import 'package:sqlite_async/sqlite_async.dart';

import '../../domain/entities/money_entry.dart';
import '../datasources/local/database_service.dart';
import '../../domain/repositories/money_repository.dart';
import '../datasources/local/sql_helpers.dart';
import '../models/money_models.dart';

class MoneyRepositoryImpl implements MoneyRepository {
  MoneyRepositoryImpl(this._db);
  final SqliteConnection _db;

  /// Stamped the first time it's asked, or carried over from the pre-cloud
  /// database. The cloud keeps the first stamp it ever receives, so a fresh
  /// install that stamps "today" before its first sync is corrected by it.
  @override
  Future<DateTime> booksStartedAt() async {
    const key = DatabaseService.booksStartedAtKey;
    final rows = await _db.query('shop_settings', where: 'id = ?', whereArgs: [key]);
    if (rows.isNotEmpty) return DateTime.parse(rows.single['value'] as String);
    final now = DateTime.now();
    await _db.insert('shop_settings', {'id': key, 'value': now.toIso8601String()});
    return now;
  }

  @override
  Future<List<MoneyEntry>> getAll() async {
    final rows = await _db.query('money_entries', orderBy: 'at DESC');
    return rows.map(moneyEntryFromMap).toList();
  }

  @override
  Future<void> add(MoneyEntry entry) => _db.insert('money_entries', moneyEntryToMap(entry));

  @override
  Future<void> update(MoneyEntry entry) =>
      _db.update('money_entries', moneyEntryToMap(entry), where: 'id = ?', whereArgs: [entry.id]);

  @override
  Future<void> delete(String id) => _db.delete('money_entries', where: 'id = ?', whereArgs: [id]);
}
