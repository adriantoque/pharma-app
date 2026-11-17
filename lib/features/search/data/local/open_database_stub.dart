/// Opens the database on whatever platform this code was compiled for.
///
/// Resolved by conditional import in `open_database.dart`: native platforms
/// get SQLite through `drift_flutter`, web gets IndexedDB-backed sql.js through
/// `drift/web.dart`, and anything else throws rather than silently losing the
/// price list.
library;

// STUB: replaced by the platform-specific files via conditional import.
import 'package:drift/drift.dart';

QueryExecutor openAppDatabase() =>
    throw UnsupportedError('No local database for this platform.');
