// The pre-cloud schema upgrades, still used when importing an old install
// (LegacyImport opens the old file through LegacyDatabase.open).

import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:skirt_tee_studio/data/sync/legacy_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('legacy upgradeSchema from v2 brings an old install up to v7', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    addTearDown(db.close);
    // Pre-v3 shape, before imagePath existed.
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        unitPrice REAL NOT NULL,
        qtyOnHand INTEGER NOT NULL,
        isBargain INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE TABLE sales (id TEXT PRIMARY KEY, dateTime TEXT NOT NULL)');
    await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute('''
      CREATE TABLE sale_line_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        unitPrice REAL NOT NULL,
        qty INTEGER NOT NULL
      )
    ''');

    await LegacyDatabase.upgradeSchema(db, 2);

    final saleColumns = await db.rawQuery('PRAGMA table_info(sales)');
    expect(saleColumns.map((c) => c['name']), containsAll(['paymentMethod', 'amountTendered']));
    final lineColumns = await db.rawQuery('PRAGMA table_info(sale_line_items)');
    expect(lineColumns.map((c) => c['name']), contains('unitCost'));
    final columns = await db.rawQuery('PRAGMA table_info(items)');
    expect(columns.map((c) => c['name']), containsAll(['imagePath', 'unitCost']));
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    expect(tables.map((t) => t['name']), containsAll(['money_entries', 'stock_lots', 'stock_movements', 'staff', 'audit_log']));
    final stamp = await db.query('settings', where: 'key = ?', whereArgs: [DatabaseService.booksStartedAtKey]);
    expect(stamp, hasLength(1), reason: 'the books start at the upgrade');
  });
}
