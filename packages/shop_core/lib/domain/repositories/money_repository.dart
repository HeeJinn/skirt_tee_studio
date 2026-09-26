import '../entities/money_entry.dart';

abstract class MoneyRepository {
  /// When the books start: profit and payback count only from here, since
  /// nothing before it was recorded. Fixed once set.
  Future<DateTime> booksStartedAt();

  /// Every entry in the owners' money log, newest first.
  Future<List<MoneyEntry>> getAll();
  Future<void> add(MoneyEntry entry);
  Future<void> update(MoneyEntry entry);
  Future<void> delete(String id);
}
