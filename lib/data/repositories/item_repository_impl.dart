import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../datasources/local/item_local_data_source.dart';
import '../models/item_model.dart';

class ItemRepositoryImpl implements ItemRepository {
  ItemRepositoryImpl(this._localDataSource);
  final ItemLocalDataSource _localDataSource;

  @override
  Future<List<Item>> getAll() => _localDataSource.getAll();

  @override
  Future<void> add(Item item) => _localDataSource.insert(ItemModel.fromEntity(item));

  @override
  Future<void> update(Item item) => _localDataSource.update(ItemModel.fromEntity(item));

  @override
  Future<void> delete(String id) => _localDataSource.delete(id);
}
