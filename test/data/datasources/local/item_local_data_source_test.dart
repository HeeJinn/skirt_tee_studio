import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/data/datasources/local/item_image_storage.dart';
import 'package:skirt_tee_studio/data/datasources/local/item_local_data_source.dart';
import 'package:skirt_tee_studio/data/models/item_model.dart';

import '../../../test_helpers.dart';

void main() {
  late ItemLocalDataSourceImpl dataSource;

  setUp(() async {
    dataSource = ItemLocalDataSourceImpl(await openTestDatabase());
  });

  test('insert then getAll returns the item', () async {
    const model = ItemModel(
      id: '1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 10,
    );
    await dataSource.insert(model);

    final all = await dataSource.getAll();
    expect(all, hasLength(1));
    expect(all.first.name, 'Basic Tee');
    expect(all.first.qtyOnHand, 10);
  });

  test('update persists changes', () async {
    const model = ItemModel(
      id: '1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 10,
    );
    await dataSource.insert(model);
    await dataSource.update(ItemModel.fromEntity(model.copyWith(qtyOnHand: 3)));

    final all = await dataSource.getAll();
    expect(all.single.qtyOnHand, 3);
    expect(all.single.isLowStock(5), isTrue);
  });

  test('a photo is stored by file name and read back as a path on this PC', () async {
    const withPhoto = ItemModel(
      id: '1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 10,
      imagePath: '/app support/item_images/abc.png',
    );
    const withoutPhoto = ItemModel(
      id: '2',
      name: 'Denim Skirt',
      category: 'Skirt',
      unitPrice: 399,
      qtyOnHand: 5,
    );
    await dataSource.insert(withPhoto);
    await dataSource.insert(withoutPhoto);

    final all = await dataSource.getAll();
    // Only the file name is stored (and synced); the folder is this PC's.
    expect(all.firstWhere((i) => i.id == '1').imagePath, ItemImageStorage.instance.pathFor('abc.png'));
    expect(all.firstWhere((i) => i.id == '2').imagePath, isNull);
  });

  test('delete removes the item', () async {
    const model = ItemModel(
      id: '1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 10,
    );
    await dataSource.insert(model);
    await dataSource.delete('1');

    expect(await dataSource.getAll(), isEmpty);
  });
}
