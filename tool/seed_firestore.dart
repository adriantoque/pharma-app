/// Seeds the authenticated user's Firestore catalogue from the bundled JSON.
///
/// Written here so it can be run once, after signing in, in case Firebase is set
/// up after the app was first built. The helper reads
/// `assets/data/medicines_seed.json` and writes all lines in batches using the
/// document id derived by [MedicineModel.documentId], so a second run updates
/// rather than duplicates.
///
/// Usage:
///   - Sign in to the app.
///   - From the root of the repository: `dart run tool/seed_firestore.dart`

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../lib/features/search/data/models/medicine_model.dart';
import '../lib/firebase_options.dart';

Future<void> main() async {
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
  final collection = firestore.collection('users').doc(uid).collection('medicines');
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
}
