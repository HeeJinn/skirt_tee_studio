import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import '../../sync/schema.dart';

/// Opens the app's local database: a PowerSync SQLite file that works fully
/// offline and, once an owner connects the shop in Settings, syncs with the
/// cloud. The pre-cloud file is imported into it once (see LegacyImport).
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const fileName = 'skirt_tee_studio_cloud.db';

  /// Shop setting for when the money books start. Sales before it carry no
  /// cost and the money behind them was never recorded, so profit and
  /// payback count from here — "start from zero", per the owners.
  static const booksStartedAtKey = 'booksStartedAt';

  PowerSyncDatabase? _db;

  Future<PowerSyncDatabase> get database async => _db ??= await _open();

  Future<Directory> get supportDirectory => getApplicationSupportDirectory();

  /// Writes a complete, transactionally-consistent snapshot to
  /// [destinationPath] via SQLite's own `VACUUM INTO` — safer than copying
  /// the live file, which risks capturing a half-written page. `VACUUM INTO`
  /// refuses to overwrite an existing file, so a prior file at the
  /// destination (the user picked an existing name to overwrite) is removed
  /// first.
  Future<void> backupTo(String destinationPath) async {
    final destination = File(destinationPath);
    if (await destination.exists()) {
      await destination.delete();
    }
    final db = await database;
    await db.execute('VACUUM INTO ?', [destinationPath]);
  }

  Future<PowerSyncDatabase> _open() async {
    final dir = await supportDirectory;
    return openAt(p.join(dir.path, fileName));
  }

  /// Shared with tests, so they run against the exact same schema.
  static Future<PowerSyncDatabase> openAt(String path) async {
    final db = PowerSyncDatabase(schema: appSchema, path: path);
    await db.initialize();
    return db;
  }
}
