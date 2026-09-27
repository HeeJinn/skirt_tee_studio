import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// How long a period is: everything on record, one calendar day, or one
/// calendar month.
enum PeriodKind { all, month, day }

/// The stretch of time a list or a total is narrowed to. Days and months
/// are calendar ones, built with DateTime's constructor rather than adding
/// durations, so they stay whole across daylight-saving changes.
@immutable
class Period {
  const Period.all()
      : kind = PeriodKind.all,
        start = null;

  Period.day(DateTime at)
      : kind = PeriodKind.day,
        start = DateTime(at.year, at.month, at.day);

  Period.month(DateTime at)
      : kind = PeriodKind.month,
        start = DateTime(at.year, at.month);

  /// Today, this month, or everything.
  factory Period.current(PeriodKind kind, DateTime now) => switch (kind) {
        PeriodKind.all => const Period.all(),
        PeriodKind.month => Period.month(now),
        PeriodKind.day => Period.day(now),
      };

  final PeriodKind kind;

  /// The first moment in the period; null for all time.
  final DateTime? start;

  /// The first moment after the period; null for all time.
  DateTime? get end => switch (kind) {
        PeriodKind.all => null,
        PeriodKind.month => DateTime(start!.year, start!.month + 1),
        PeriodKind.day => DateTime(start!.year, start!.month, start!.day + 1),
      };

  bool contains(DateTime at) {
    final end = this.end;
    return (start == null || !at.isBefore(start!)) && (end == null || at.isBefore(end));
  }

  /// The period [by] days or months later (earlier when negative).
  Period shift(int by) => switch (kind) {
        PeriodKind.all => this,
        PeriodKind.month => Period.month(DateTime(start!.year, start!.month + by)),
        PeriodKind.day => Period.day(DateTime(start!.year, start!.month, start!.day + by)),
      };

  /// Whether [now] falls in it, so there's nothing later to step to.
  bool isCurrent(DateTime now) => contains(now);

  /// The same stretch of time as a [kind] period: a day becomes its month;
  /// a month becomes today if it's this month, or else its last day.
  Period asKind(PeriodKind kind, DateTime now) {
    if (kind == this.kind) return this;
    return switch ((this.kind, kind)) {
      (_, PeriodKind.all) => const Period.all(),
      (PeriodKind.all, _) => Period.current(kind, now),
      (PeriodKind.day, PeriodKind.month) => Period.month(start!),
      _ => isCurrent(now) ? Period.day(now) : Period.day(DateTime(start!.year, start!.month + 1, 0)),
    };
  }

  /// "Today, Sep 26", "Yesterday, Sep 25", "Thu, Sep 24", "September 2026",
  /// or "All time". A day in another year carries its year.
  String label(DateTime now) {
    switch (kind) {
      case PeriodKind.all:
        return 'All time';
      case PeriodKind.month:
        return DateFormat('MMMM y').format(start!);
      case PeriodKind.day:
        final day = start!;
        final today = DateTime(now.year, now.month, now.day);
        if (day == today) return 'Today, ${DateFormat('MMM d').format(day)}';
        if (day == DateTime(now.year, now.month, now.day - 1)) return 'Yesterday, ${DateFormat('MMM d').format(day)}';
        return DateFormat(day.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(day);
    }
  }

  /// How the period ends a sentence ("No sales …"): "today", "yesterday",
  /// "on Thu, Sep 24", "in September 2026", or "yet".
  String phrase(DateTime now) => switch (kind) {
        PeriodKind.all => 'yet',
        PeriodKind.day when isCurrent(now) => 'today',
        PeriodKind.day when shift(1).isCurrent(now) => 'yesterday',
        PeriodKind.day => 'on ${label(now)}',
        PeriodKind.month => 'in ${label(now)}',
      };

  @override
  bool operator ==(Object other) => other is Period && other.kind == kind && other.start == start;

  @override
  int get hashCode => Object.hash(kind, start);

  @override
  String toString() => 'Period(${kind.name}, $start)';
}

/// Items bucketed by calendar day or month, keeping the items' own order
/// (newest first in, newest first out).
List<(DateTime, List<T>)> groupByDate<T>(Iterable<T> items, DateTime Function(T) dateOf, {required bool byMonth}) {
  final groups = <DateTime, List<T>>{};
  for (final item in items) {
    final at = dateOf(item);
    final key = byMonth ? DateTime(at.year, at.month) : DateTime(at.year, at.month, at.day);
    groups.putIfAbsent(key, () => []).add(item);
  }
  return [for (final MapEntry(:key, :value) in groups.entries) (key, value)];
}
