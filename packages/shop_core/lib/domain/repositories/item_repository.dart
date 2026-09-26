import '../entities/item.dart';

abstract class ItemRepository {
  Future<List<Item>> getAll();
  Future<void> add(Item item);
  Future<void> update(Item item);
  Future<void> delete(String id);
}
