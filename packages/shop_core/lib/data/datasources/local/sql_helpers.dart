import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

/// sqflite-style helpers over sqlite_async (what PowerSync is built on), so
/// the data sources read the same as they did before the cloud move.
/// Table and column names come from this app's code, never from user input.
extension SqlReadHelpers on SqliteReadContext {
  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?> whereArgs = const [],
    String? orderBy,
    int? limit,
  }) async {
    final sql = StringBuffer('SELECT ${columns?.join(', ') ?? '*'} FROM $table');
    if (where != null) sql.write(' WHERE $where');
    if (orderBy != null) sql.write(' ORDER BY $orderBy');
    if (limit != null) sql.write(' LIMIT $limit');
    return (await getAll(sql.toString(), whereArgs)).toList();
  }
}

extension SqlWriteHelpers on SqliteWriteContext {
  static const _uuid = Uuid();

  /// PowerSync tables need a text id; rows that never had one of their own
  /// (sale line items, stock movements, the audit log) get a fresh UUID.
  Future<void> insert(String table, Map<String, Object?> values) {
    final row = values.containsKey('id') ? values : {'id': _uuid.v4(), ...values};
    final columns = row.keys.join(', ');
    final placeholders = List.filled(row.length, '?').join(', ');
    return execute('INSERT INTO $table ($columns) VALUES ($placeholders)', row.values.toList());
  }

  Future<void> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    List<Object?> whereArgs = const [],
  }) {
    final assignments = values.keys.map((c) => '$c = ?').join(', ');
    return execute('UPDATE $table SET $assignments WHERE $where', [...values.values, ...whereArgs]);
  }

  Future<void> delete(String table, {required String where, List<Object?> whereArgs = const []}) =>
      execute('DELETE FROM $table WHERE $where', whereArgs);

  /// Insert-or-update by id. PowerSync's tables are views, which don't take
  /// `INSERT OR REPLACE`, so this checks first.
  Future<void> upsert(String table, String id, Map<String, Object?> values) async {
    final existing = await getOptional('SELECT 1 FROM $table WHERE id = ?', [id]);
    if (existing == null) {
      await insert(table, {'id': id, ...values});
    } else {
      await update(table, values, where: 'id = ?', whereArgs: [id]);
    }
  }
}
