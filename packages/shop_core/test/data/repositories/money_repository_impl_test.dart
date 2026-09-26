import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/data/repositories/money_repository_impl.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:sqlite_async/sqlite_async.dart';

import '../../test_helpers.dart';

void main() {
  late SqliteConnection db;
  late MoneyRepositoryImpl repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = MoneyRepositoryImpl(db);
  });

  test('the books start date is stamped once and then kept', () async {
    final first = await repo.booksStartedAt();
    expect(await repo.booksStartedAt(), first);
  });

  test('a sync that drops the start date does not make it re-stamp over and over', () async {
    final first = await repo.booksStartedAt();
    // What a download without the setting does to this PC's copy.
    await db.execute('DELETE FROM shop_settings');

    expect(await repo.booksStartedAt(), first, reason: 'same date back, no new stamp');
    final queued = await db.getAll("SELECT data FROM ps_crud WHERE data LIKE '%booksStartedAt%'");
    expect(queued.where((r) => (r['data'] as String).contains('"PUT"')), hasLength(1));
  });

  test('entries round-trip every field, newest first', () async {
    await repo.add(MoneyEntry(
      id: 'rent',
      at: DateTime(2026, 9, 1),
      kind: MoneyEntryKind.expense,
      amount: 8000,
      category: ExpenseCategory.rent,
      paidFrom: PaidFrom.owners,
      person: 'Ben',
      note: 'September',
    ));
    await repo.add(MoneyEntry(id: 'draw', at: DateTime(2026, 9, 15), kind: MoneyEntryKind.ownerDraw, amount: 5000));

    final all = await repo.getAll();
    expect(all.map((e) => e.id), ['draw', 'rent']);
    final rent = all.last;
    expect(rent.kind, MoneyEntryKind.expense);
    expect(rent.amount, 8000);
    expect(rent.category, ExpenseCategory.rent);
    expect(rent.paidFrom, PaidFrom.owners);
    expect(rent.person, 'Ben');
    expect(rent.note, 'September');
    expect(all.first.category, isNull);
    expect(all.first.person, isNull);
  });

  test('booksStartedAt is stamped by the schema and never moves', () async {
    final first = await repo.booksStartedAt();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(await repo.booksStartedAt(), first);
    expect(DateTime.now().difference(first).inMinutes, lessThan(1));
  });

  test('update and delete', () async {
    final entry = MoneyEntry(id: 'e', at: DateTime(2026, 9, 1), kind: MoneyEntryKind.capitalIn, amount: 50000);
    await repo.add(entry);

    await repo.update(MoneyEntry(id: 'e', at: entry.at, kind: entry.kind, amount: 60000));
    expect((await repo.getAll()).single.amount, 60000);

    await repo.delete('e');
    expect(await repo.getAll(), isEmpty);
  });
}
