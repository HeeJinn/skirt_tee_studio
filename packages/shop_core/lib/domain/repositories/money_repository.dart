import '../entities/money_entry.dart';

abstract class MoneyRepository {
  /// When the books start: profit and payback count only from here, since
  /// nothing before it was recorded. Fixed once set.
  Future<DateTime> booksStartedAt();

  /// The same date without stamping one: null until the books have started
  /// (or, on the owner app, until the shop computer's stamp has synced).
  /// For readers that must never write.
  Future<DateTime?> booksStartedAtIfSet();

  /// Every entry in the owners' money log, newest first.
  Future<List<MoneyEntry>> getAll();
  Future<void> add(MoneyEntry entry);
  Future<void> update(MoneyEntry entry);
  Future<void> delete(String id);
}
