// Exercises the VACUUM INTO mechanism DatabaseService.backupTo relies on
// (parameter-bound destination path, produces a standalone readable file)
// directly against a test database, rather than through the singleton
// (which also resolves a real on-disk path via path_provider).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:skirt_tee_studio/data/datasources/local/database_service.dart';
import 'package:skirt_tee_studio/data/datasources/local/item_local_data_source.dart';
import 'package:skirt_tee_studio/data/models/item_model.dart';

import '../../../test_helpers.dart';

void main() {
  test('VACUUM INTO produces a standalone file with the same data', () async {
    final db = await openTestDatabase();
    final itemDataSource = ItemLocalDataSourceImpl(db);
    await itemDataSource.insert(const ItemModel(
      id: 'item-1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 10,
    ));

    final tempDir = await Directory.systemTemp.createTemp('skirt_tee_backup_test');
    final backupPath = '${tempDir.path}/backup.db';
    addTearDown(() => tempDir.delete(recursive: true));

    await db.execute('VACUUM INTO ?', [backupPath]);

    expect(await File(backupPath).exists(), isTrue);
    final restored = await databaseFactoryFfi.openDatabase(backupPath);
    final restoredItems = await ItemLocalDataSourceImpl(restored).getAll();
    expect(restoredItems.single.name, 'Basic Tee');
    await restored.close();
  });

  test('VACUUM INTO refuses to overwrite an existing file', () async {
    final db = await openTestDatabase();
    final tempDir = await Directory.systemTemp.createTemp('skirt_tee_backup_test');
    final backupPath = '${tempDir.path}/backup.db';
    addTearDown(() => tempDir.delete(recursive: true));
    await File(backupPath).writeAsString('not a real db');

    await expectLater(
      () => db.execute('VACUUM INTO ?', [backupPath]),
      throwsA(anything),
    );
  });

  test('upgradeSchema from v2 adds the imagePath column to an existing items table', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
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

    await DatabaseService.upgradeSchema(db, 2);

    final saleColumns = await db.rawQuery('PRAGMA table_info(sales)');
    expect(saleColumns.map((c) => c['name']), containsAll(['paymentMethod', 'amountTendered']));
    final lineColumns = await db.rawQuery('PRAGMA table_info(sale_line_items)');
    expect(lineColumns.map((c) => c['name']), contains('unitCost'));
    final columns = await db.rawQuery('PRAGMA table_info(items)');
    expect(columns.map((c) => c['name']), containsAll(['imagePath', 'unitCost']));
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    expect(tables.map((t) => t['name']), containsAll(['money_entries', 'stock_lots', 'stock_movements']));
    final stamp = await db.query('settings', where: 'key = ?', whereArgs: [DatabaseService.booksStartedAtKey]);
    expect(stamp, hasLength(1), reason: 'the books start at the upgrade');
    // Column must actually be usable, not just declared.
    await ItemLocalDataSourceImpl(db).insert(const ItemModel(
      id: '1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 10,
      imagePath: '/some/path.png',
    ));
    final items = await ItemLocalDataSourceImpl(db).getAll();
    expect(items.single.imagePath, '/some/path.png');
  });
}
