// Provides SQLite to the Drift-backed tests.
//
// `package:sqlite3` resolves its native library through Dart's native assets:
// the first test run compiles or fetches it, and every run after that reuses
// it. When that machinery is not available on a machine, the database-backed
// tests skip rather than fail -- the store logic is covered database-free by
// the codec, merge and synced store suites.
library;

import 'package:drift/native.dart';
import 'package:pharmaguide/features/search/data/local/app_database.dart';

/// Resolved once, before any test registers, and passed into `skip:`.
Future<bool> get sqlite3Available async => _probe();

/// Opens a database just to find out whether SQLite works at all.
Future<bool> _probe() async {
  AppDatabase? probe;
  try {
    probe = AppDatabase.forTesting(NativeDatabase.memory());
    await probe.select(probe.medicineRows).get();
    return true;
  } catch (_) {
    return false;
  } finally {
    await probe?.close();
  }
}

/// An in-memory database for one test, fresh every time.
AppDatabase openInMemoryAppDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());
