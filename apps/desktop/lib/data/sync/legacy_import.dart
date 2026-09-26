import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite_async/sqlite_async.dart';

import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:shop_core/data/datasources/local/item_image_storage.dart';
import 'package:shop_core/data/datasources/local/sql_helpers.dart';
import 'legacy_database.dart';

/// Moves an existing shop's pre-cloud data into the new database, once.
///
/// The old file is never modified or deleted: a raw copy is kept next to it
/// as `skirt_tee_studio.pre-cloud.db`, and the import itself is one local
/// transaction, so a crash part-way leaves nothing behind and simply runs
/// again next launch. Imported rows join the upload queue like any other
/// change and go up the first time the shop is connected.
class LegacyImport {
  LegacyImport._();

  static const backupFileName = 'skirt_tee_studio.pre-cloud.db';

  /// Device setting recording that the import ran (or wasn't needed).
  static const doneKey = 'legacyImportedAt';

  /// Shop-wide settings; any other legacy setting is a per-PC preference.
  static const _shopSettingKeys = {'lowStockThreshold', DatabaseService.booksStartedAtKey};

  /// Tables copied as they are; the pre-cloud integer ids of line items,
  /// movements and the audit log are dropped for fresh UUIDs.
  static const _tables = [
    'items',
    'sales',
    'sale_line_items',
    'reservations',
    'money_entries',
    'stock_lots',
    'stock_movements',
    'audit_log',
    'staff',
  ];
  static const _integerIdTables = {'sale_line_items', 'stock_movements', 'audit_log'};

  /// Returns true when data was imported.
  static Future<bool> runIfNeeded(SqliteConnection db, String supportDirectory) async {
    final legacyFile = File(p.join(supportDirectory, LegacyDatabase.fileName));
    if (await _isDone(db) || !await legacyFile.exists()) return false;

    final backup = File(p.join(supportDirectory, backupFileName));
    if (!await backup.exists()) await legacyFile.copy(backup.path);

    final legacy = await LegacyDatabase.open(legacyFile.path);
    try {
      final rowsByTable = {for (final t in _tables) t: await legacy.query(t)};
      final settings = await legacy.query('settings');

      return await db.writeTransaction((txn) async {
        // Something already filled this database (e.g. a download from the
        // cloud): importing on top would double every sale.
        if (await _hasShopData(txn)) {
          await _markDone(txn);
          return false;
        }
        for (final table in _tables) {
          for (final row in rowsByTable[table]!) {
            await txn.insert(table, _convert(table, row));
          }
        }
        for (final row in settings) {
          final key = row['key'] as String;
          final table = _shopSettingKeys.contains(key) ? 'shop_settings' : 'device_settings';
          await txn.upsert(table, key, {'value': row['value']});
        }
        await _markDone(txn);
        return rowsByTable.values.any((rows) => rows.isNotEmpty);
      });
    } finally {
      await legacy.close();
    }
  }

  static Map<String, Object?> _convert(String table, Map<String, Object?> row) {
    final out = Map<String, Object?>.of(row);
    if (_integerIdTables.contains(table)) out.remove('id');
    if (table == 'items') {
      final path = out.remove('imagePath') as String?;
      out['imageKey'] = path == null ? null : ItemImageStorage.keyFor(path);
    }
    return out;
  }

  static Future<bool> _isDone(SqliteReadContext db) async =>
      await db.getOptional('SELECT 1 FROM device_settings WHERE id = ?', [doneKey]) != null;

  static Future<bool> _hasShopData(SqliteReadContext db) async {
    for (final table in ['items', 'sales', 'money_entries', 'stock_lots']) {
      if (await db.getOptional('SELECT 1 FROM $table LIMIT 1') != null) return true;
    }
    return false;
  }

  static Future<void> _markDone(SqliteWriteContext txn) =>
      txn.upsert('device_settings', doneKey, {'value': DateTime.now().toIso8601String()});
}
