import 'package:drift/drift.dart';
import 'package:drift/web.dart';

// drift's web backend builds on sql.js; the package marks the entry point
// deprecated in favour of the WASM build, which this app does not ship yet.
// ignore_for_file: deprecated_member_use

/// Web.
///
/// IndexedDB through sql.js rather than the WASM build, which would need
/// `sqlite3.wasm` and a worker script shipped as build assets. The API is the
/// same [QueryExecutor], so nothing above this file knows the difference.
QueryExecutor openAppDatabase() => WebDatabase('pharmaguide_medicines');
