import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:skirt_tee_studio/data/datasources/local/database_service.dart';

bool _ffiInitialized = false;

/// Opens a fresh, independent in-memory database with the app's schema, for
/// tests. `singleInstance: false` is required — otherwise sqflite hands back
/// the same cached ":memory:" connection (with leftover rows) to every test.
Future<Database> openTestDatabase() async {
  if (!_ffiInitialized) {
    sqfliteFfiInit();
    _ffiInitialized = true;
  }
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: DatabaseService.schemaVersion,
      onCreate: (db, version) => DatabaseService.createSchema(db),
      singleInstance: false,
    ),
  );
}
