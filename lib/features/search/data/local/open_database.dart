export 'open_database_stub.dart'
    if (dart.library.io) 'open_database_native.dart'
    if (dart.library.html) 'open_database_web.dart';
