import 'package:sqlite_async/sqlite_async.dart';

import '../../models/item_model.dart';
import 'sql_helpers.dart';

abstract class ItemLocalDataSource {
  Future<List<ItemModel>> getAll();
  Future<void> insert(ItemModel model);
  Future<void> update(ItemModel model);
  Future<void> delete(String id);
}

class ItemLocalDataSourceImpl implements ItemLocalDataSource {
  ItemLocalDataSourceImpl(this._db);
  final SqliteConnection _db;

  @override
  Future<List<ItemModel>> getAll() async {
    final rows = await _db.query('items', orderBy: 'name');
    return rows.map(ItemModel.fromMap).toList();
  }

  @override
  Future<void> insert(ItemModel model) => _db.insert('items', model.toMap());

  @override
  Future<void> update(ItemModel model) => _db.update(
        'items',
        model.toMap(),
        where: 'id = ?',
        whereArgs: [model.id],
      );

  @override
  Future<void> delete(String id) => _db.delete(
        'items',
        where: 'id = ?',
        whereArgs: [id],
      );
}
