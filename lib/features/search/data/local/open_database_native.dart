import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Native platforms (Android, iOS, desktop).
///
/// `driftDatabase` locates the file with `path_provider` and runs SQLite on a
/// background isolate, so a slow read never janks the price-list UI. The file
/// lives in the app's documents directory and survives a restart by design --
/// that durability is the whole point of the cache.
QueryExecutor openAppDatabase() => driftDatabase(name: 'pharmaguide_medicines');
