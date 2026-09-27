import '../domain/entities/money_entry.dart';
import '../domain/repositories/money_repository.dart';

class FakeMoneyRepository implements MoneyRepository {
  FakeMoneyRepository({DateTime? booksStartedAt}) : _booksStartedAt = booksStartedAt ?? DateTime(2026, 1, 1);

  final DateTime _booksStartedAt;
  final List<MoneyEntry> _entries = [];

  @override
  Future<DateTime> booksStartedAt() async => _booksStartedAt;

  @override
  Future<DateTime?> booksStartedAtIfSet() async => _booksStartedAt;

  @override
  Future<List<MoneyEntry>> getAll() async => List.unmodifiable(_entries..sort((a, b) => b.at.compareTo(a.at)));

  @override
  Future<void> add(MoneyEntry entry) async => _entries.add(entry);

  @override
  Future<void> update(MoneyEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    _entries[index] = entry;
  }

  @override
  Future<void> delete(String id) async => _entries.removeWhere((e) => e.id == id);
}
