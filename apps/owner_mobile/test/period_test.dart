import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/core/period.dart';

void main() {
  final now = DateTime(2026, 9, 26, 15);

  test('a day runs from midnight to midnight', () {
    final day = Period.day(DateTime(2026, 9, 24, 13));
    expect(day.start, DateTime(2026, 9, 24));
    expect(day.end, DateTime(2026, 9, 25));
    expect(day.contains(DateTime(2026, 9, 24)), isTrue);
    expect(day.contains(DateTime(2026, 9, 24, 23, 59)), isTrue);
    expect(day.contains(DateTime(2026, 9, 25)), isFalse);
    expect(day.contains(DateTime(2026, 9, 23, 23, 59)), isFalse);
  });

  test('a month runs from its 1st to the next 1st', () {
    final month = Period.month(DateTime(2026, 2, 14));
    expect(month.start, DateTime(2026, 2));
    expect(month.end, DateTime(2026, 3));
    expect(month.contains(DateTime(2026, 2, 28, 23)), isTrue);
    expect(month.contains(DateTime(2026, 3, 1)), isFalse);
  });

  test('all time holds everything', () {
    const all = Period.all();
    expect(all.contains(DateTime(1999)), isTrue);
    expect(all.contains(DateTime(2099)), isTrue);
    expect(all.shift(-1), all);
  });

  test('steps across month and year ends', () {
    expect(Period.day(DateTime(2026, 3, 1)).shift(-1), Period.day(DateTime(2026, 2, 28)));
    expect(Period.day(DateTime(2026, 12, 31)).shift(1), Period.day(DateTime(2027, 1, 1)));
    expect(Period.month(DateTime(2026, 1)).shift(-1), Period.month(DateTime(2025, 12)));
    expect(Period.month(DateTime(2026, 12)).shift(1), Period.month(DateTime(2027, 1)));
  });

  test('switching kind stays near the same time', () {
    expect(Period.day(DateTime(2026, 8, 3)).asKind(PeriodKind.month, now), Period.month(DateTime(2026, 8)));
    expect(Period.month(now).asKind(PeriodKind.day, now), Period.day(now), reason: 'this month opens on today');
    expect(Period.month(DateTime(2026, 2)).asKind(PeriodKind.day, now), Period.day(DateTime(2026, 2, 28)),
        reason: 'a past month opens on its last day');
    expect(const Period.all().asKind(PeriodKind.day, now), Period.day(now));
    expect(Period.day(now).asKind(PeriodKind.all, now), const Period.all());
  });

  test('labels read naturally', () {
    expect(Period.day(now).label(now), 'Today, Sep 26');
    expect(Period.day(DateTime(2026, 9, 25)).label(now), 'Yesterday, Sep 25');
    expect(Period.day(DateTime(2026, 9, 24)).label(now), 'Thu, Sep 24');
    expect(Period.day(DateTime(2025, 9, 24)).label(now), 'Wed, Sep 24, 2025');
    expect(Period.month(now).label(now), 'September 2026');
    expect(const Period.all().label(now), 'All time');

    expect(Period.day(now).phrase(now), 'today');
    expect(Period.day(DateTime(2026, 9, 25)).phrase(now), 'yesterday');
    expect(Period.day(DateTime(2026, 9, 24)).phrase(now), 'on Thu, Sep 24');
    expect(Period.month(now).phrase(now), 'in September 2026');
  });

  test('groups by day or by month, keeping order', () {
    final dates = [DateTime(2026, 9, 26, 14), DateTime(2026, 9, 26, 9), DateTime(2026, 9, 2), DateTime(2026, 8, 30)];
    final byDay = groupByDate(dates, (d) => d, byMonth: false);
    expect(byDay.map((g) => (g.$1, g.$2.length)), [
      (DateTime(2026, 9, 26), 2),
      (DateTime(2026, 9, 2), 1),
      (DateTime(2026, 8, 30), 1),
    ]);
    final byMonth = groupByDate(dates, (d) => d, byMonth: true);
    expect(byMonth.map((g) => (g.$1, g.$2.length)), [(DateTime(2026, 9), 3), (DateTime(2026, 8), 1)]);
  });
}
