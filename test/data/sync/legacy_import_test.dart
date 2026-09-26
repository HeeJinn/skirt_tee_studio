import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart';
import 'package:skirt_tee_studio/data/datasources/local/database_service.dart';
import 'package:skirt_tee_studio/data/datasources/local/item_image_storage.dart';
import 'package:skirt_tee_studio/data/datasources/local/item_local_data_source.dart';
import 'package:skirt_tee_studio/data/datasources/local/sale_local_data_source.dart';
import 'package:skirt_tee_studio/data/datasources/local/settings_local_data_source.dart';
import 'package:skirt_tee_studio/data/repositories/money_repository_impl.dart';
import 'package:skirt_tee_studio/data/repositories/staff_repository_impl.dart';
import 'package:skirt_tee_studio/data/repositories/stock_repository_impl.dart';
import 'package:skirt_tee_studio/data/sync/legacy_database.dart';
import 'package:skirt_tee_studio/data/sync/legacy_import.dart';
import 'package:skirt_tee_studio/domain/entities/stock.dart';

void main() {
  late Directory dir;
  late PowerSyncDatabase db;

  /// A v7 pre-cloud shop: one of everything, written the way the old app did.
  Future<void> writeLegacyShop() async {
    final legacy = await LegacyDatabase.open(p.join(dir.path, LegacyDatabase.fileName));
    await legacy.delete('settings'); // drop the "now" stamp createSchema adds
    await legacy.insert('settings', {'key': DatabaseService.booksStartedAtKey, 'value': '2026-03-01T09:00:00.000'});
    await legacy.insert('settings', {'key': 'lowStockThreshold', 'value': '3'});
    await legacy.insert('settings', {'key': 'themePreset', 'value': 'blush'});
    await legacy.insert('items', {
      'id': 'tee',
      'name': 'Basic Tee',
      'category': 'T-Shirt',
      'unitPrice': 150.0,
      'qtyOnHand': 8,
      'isBargain': 1,
      'imagePath': r'C:\Users\shop\AppData\Roaming\skirt_tee_studio\item_images\abc.png',
      'unitCost': 90.0,
    });
    await legacy.insert('sales', {'id': 'sale-1', 'dateTime': '2026-03-02T10:00:00.000', 'paymentMethod': 'cash', 'amountTendered': 500.0});
    await legacy.insert('sale_line_items', {'saleId': 'sale-1', 'itemId': 'tee', 'itemName': 'Basic Tee', 'unitPrice': 150.0, 'qty': 2, 'unitCost': 90.0});
    await legacy.insert('reservations', {
      'id': 'res-1',
      'customerName': 'Bea',
      'contact': '0917',
      'itemId': 'tee',
      'itemName': 'Basic Tee',
      'pickupDate': '2026-03-05T00:00:00.000',
      'status': 'pending',
    });
    await legacy.insert('money_entries', {
      'id': 'm-1',
      'at': '2026-03-01T09:00:00.000',
      'kind': 'capitalIn',
      'amount': 10000.0,
      'paidFrom': 'owners',
      'person': 'Ana',
      'note': '',
    });
    await legacy.insert('stock_lots', {
      'id': 'lot-1',
      'at': '2026-03-01T10:00:00.000',
      'supplier': 'Divisoria bale',
      'itemsCost': 900.0,
      'fees': 0.0,
      'paidFrom': 'owners',
      'note': '',
    });
    await legacy.insert('stock_movements', {
      'at': '2026-03-01T10:00:00.000',
      'itemId': 'tee',
      'itemName': 'Basic Tee',
      'type': 'received',
      'qty': 10,
      'unitCost': 90.0,
      'lotId': 'lot-1',
      'note': '',
    });
    await legacy.insert('staff', {'id': 'owner-1', 'name': 'Ana', 'role': 'owner', 'pinHash': 'hash', 'salt': 'salt'});
    await legacy.insert('audit_log', {'at': '2026-03-02T10:00:00.000', 'staffName': 'Ana', 'action': 'Sale ₱300.00'});
    await legacy.close();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('skirt_tee_import_test');
    ItemImageStorage.instance.useDirectory(p.join(dir.path, 'item_images'));
    db = await DatabaseService.openAt(p.join(dir.path, DatabaseService.fileName));
  });

  tearDown(() async {
    await db.close();
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Windows can hold the file a moment after close.
    }
  });

  test('brings every table across, with the same values', () async {
    await writeLegacyShop();

    expect(await LegacyImport.runIfNeeded(db, dir.path), isTrue);

    final item = (await ItemLocalDataSourceImpl(db).getAll()).single;
    expect(item.qtyOnHand, 8);
    expect(item.isBargain, isTrue);
    expect(item.unitCost, 90);
    expect(item.imagePath, ItemImageStorage.instance.pathFor('abc.png'), reason: 'photo kept by file name');

    final sale = (await SaleLocalDataSourceImpl(db).getAll()).single;
    expect(sale.amountTendered, 500);
    expect(sale.lineItems.single.qty, 2);
    expect(sale.lineItems.single.unitCost, 90);

    final money = MoneyRepositoryImpl(db);
    expect(await money.booksStartedAt(), DateTime(2026, 3, 1, 9), reason: 'the books keep their original start');
    expect((await money.getAll()).single.amount, 10000);

    final stock = StockRepositoryImpl(db);
    expect((await stock.getLots()).single.totalCost, 900);
    final movement = (await stock.getMovements()).single;
    expect(movement.type, StockMovementType.received);
    expect(movement.lotId, 'lot-1');

    final settings = SettingsLocalDataSourceImpl(db);
    expect(await settings.getLowStockThreshold(), 3);
    expect(await settings.getThemePresetId(), 'blush');

    final staff = StaffRepositoryImpl(db);
    expect((await staff.getAll()).single.name, 'Ana');
    expect((await staff.recentActivity()).single.action, 'Sale ₱300.00');
  });

  test('queues the shop data for upload, but never staff PINs or this PC\'s theme', () async {
    await writeLegacyShop();
    await LegacyImport.runIfNeeded(db, dir.path);

    final upload = await db.getNextCrudTransaction();
    final tables = upload!.crud.map((op) => op.table).toSet();
    expect(tables, containsAll(['items', 'sales', 'sale_line_items', 'shop_settings', 'audit_log']));
    expect(tables, isNot(contains('staff')));
    expect(tables, isNot(contains('device_settings')));
  });

  test('keeps a copy of the old file and leaves the original alone', () async {
    await writeLegacyShop();
    final original = File(p.join(dir.path, LegacyDatabase.fileName));
    final before = await original.readAsBytes();

    await LegacyImport.runIfNeeded(db, dir.path);

    expect(await File(p.join(dir.path, LegacyImport.backupFileName)).readAsBytes(), before);
    expect(await original.exists(), isTrue);
  });

  test('runs only once', () async {
    await writeLegacyShop();
    await LegacyImport.runIfNeeded(db, dir.path);

    expect(await LegacyImport.runIfNeeded(db, dir.path), isFalse);
    expect(await SaleLocalDataSourceImpl(db).getAll(), hasLength(1), reason: 'no doubled sales');
  });

  test('does nothing on a fresh install with no old database', () async {
    expect(await LegacyImport.runIfNeeded(db, dir.path), isFalse);
    expect(await ItemLocalDataSourceImpl(db).getAll(), isEmpty);
  });

  test('skips when this database already has shop data, e.g. from the cloud', () async {
    await writeLegacyShop();
    await db.execute(
      "INSERT INTO items (id, name, category, unitPrice, qtyOnHand, isBargain) VALUES ('cloud', 'From cloud', 'Skirt', 1, 1, 0)",
    );

    expect(await LegacyImport.runIfNeeded(db, dir.path), isFalse);
    expect((await ItemLocalDataSourceImpl(db).getAll()).single.id, 'cloud');
  });
}
