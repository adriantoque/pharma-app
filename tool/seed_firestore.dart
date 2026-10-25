// Syncs the authenticated user's Firestore catalogue with the bundled JSON.
//
// Written here so it can be run once, after signing in, in case Firebase is set
// up after the app was first built. The helper reads
// `assets/data/medicines_seed.json` and writes all lines in batches using the
// document id derived by [MedicineModel.documentId], so a second run updates
// rather than duplicates.
//
// It then removes documents whose id is not in the seed, so the collection ends
// up matching the file rather than growing forever as products are retired.
// Pass `--keep-extra` to upload without deleting anything.
//
// Usage:
//   - Sign in to the app.
//   - From the root of the repository: `dart run tool/seed_firestore.dart`
//   - Add `--keep-extra` to leave products missing from the seed untouched.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/firebase_options.dart';

Future<void> main(List<String> args) async {
  final keepExtra = args.contains('--keep-extra');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    stderr.writeln('Not signed in. Sign in to the app first.');
    exit(1);
  }
  final uid = auth.currentUser!.uid;

  final file = File('assets/data/medicines_seed.json');
  if (!file.existsSync()) {
    stderr.writeln('Missing ${file.path}');
    exit(1);
  }

  final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  final medicines = [
    for (final entry in decoded)
      if (entry is Map<String, dynamic>) MedicineModel.fromFirestore(entry),
  ];

  final firestore = FirebaseFirestore.instance;
  // The path the app actually reads: one shared catalogue for every account,
  // not a per-user copy. The per-user path this used to write was left behind
  // when the store moved to `pharmacy/medicines/items`.
  final collection = firestore
      .collection('pharmacy')
      .doc('medicines')
      .collection('items');
  final batch = firestore.batch();
  var pending = 0;
  const batchLimit = 500;

  for (final medicine in medicines) {
    batch.set(collection.doc(medicine.documentId), {
      ...medicine.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (++pending == batchLimit) {
      await batch.commit();
      pending = 0;
      stdout.writeln('Committed $batchLimit lines');
    }
  }
  if (pending > 0) {
    await batch.commit();
    stdout.writeln('Committed $pending lines');
  }
  stdout.writeln('Seeded ${medicines.length} medicines for $uid');

  if (keepExtra) {
    stdout.writeln('Kept extra documents (--keep-extra)');
    return;
  }

  // A product removed from the workbook must disappear from the catalogue too,
  // otherwise "replace the list" only ever adds. Deleting by id rather than
  // clearing the collection keeps the documents that match untouched, so their
  // counters and expiry dates are not rewritten by the sync itself.
  final seededIds = {for (final medicine in medicines) medicine.documentId};
  final existing = await collection.get();
  final stale = [
    for (final doc in existing.docs)
      if (!seededIds.contains(doc.id)) doc.id,
  ];

  if (stale.isEmpty) {
    stdout.writeln('No extra documents to remove');
    return;
  }

  var deleteBatch = firestore.batch();
  var deletePending = 0;
  for (final id in stale) {
    deleteBatch.delete(collection.doc(id));
    if (++deletePending == batchLimit) {
      await deleteBatch.commit();
      stdout.writeln('Removed $batchLimit stale documents');
      deletePending = 0;
      // A committed batch cannot take more writes, so start a fresh one.
      deleteBatch = firestore.batch();
    }
  }
  if (deletePending > 0) {
    await deleteBatch.commit();
    stdout.writeln('Removed $deletePending stale documents');
  }
  stdout.writeln('Catalogue now matches the seed (${stale.length} removed)');
}
