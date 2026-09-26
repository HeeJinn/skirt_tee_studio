// Exercises the VACUUM INTO mechanism DatabaseService.backupTo relies on
// (parameter-bound destination path, produces a standalone readable file)
// directly against a test database, rather than through the singleton
// (which also resolves a real on-disk path via path_provider).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:shop_core/data/datasources/local/item_local_data_source.dart';
import 'package:shop_core/data/models/item_model.dart';

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

    await db.execute('VACUUM INTO ?', [backupPath]);

    expect(await File(backupPath).exists(), isTrue);
    final restored = await DatabaseService.openAt(backupPath);
    final restoredItems = await ItemLocalDataSourceImpl(restored).getAll();
    expect(restoredItems.single.name, 'Basic Tee');
    await restored.close();
    await tempDir.delete(recursive: true);
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
}
