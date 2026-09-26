import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/repositories/item_repository.dart';

class FakeItemRepository implements ItemRepository {
  final List<Item> _items = [];

  @override
  Future<List<Item>> getAll() async => List.unmodifiable(_items);

  @override
  Future<void> add(Item item) async => _items.add(item);

  @override
  Future<void> update(Item item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    _items[index] = item;
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((i) => i.id == id);
}
