import '../../../domain/entities/reservation.dart';

enum ReservationBucket { overdue, today, upcoming, pickedUp }

extension ReservationBucketLabel on ReservationBucket {
  String get label => switch (this) {
        ReservationBucket.overdue => 'Overdue',
        ReservationBucket.today => 'Due today',
        ReservationBucket.upcoming => 'Upcoming',
        ReservationBucket.pickedUp => 'Picked up',
      };
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from today to [pickup] — negative when it's past.
int daysUntilPickup(DateTime pickup, DateTime now) => _day(pickup).difference(_day(now)).inDays;

ReservationBucket bucketOf(Reservation r, DateTime now) {
  if (r.status == ReservationStatus.pickedUp) return ReservationBucket.pickedUp;
  final days = daysUntilPickup(r.pickupDate, now);
  if (days < 0) return ReservationBucket.overdue;
  if (days == 0) return ReservationBucket.today;
  return ReservationBucket.upcoming;
}

/// "Today", "Tomorrow", "In 4 days", "2 days overdue".
String relativePickupLabel(DateTime pickup, DateTime now) {
  final days = daysUntilPickup(pickup, now);
  if (days < 0) return '${-days} day${days == -1 ? '' : 's'} overdue';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}

/// Buckets in display order, each sorted so the most actionable is first:
/// overdue oldest-first, today/upcoming soonest-first, picked up newest-first.
Map<ReservationBucket, List<Reservation>> groupReservations(List<Reservation> reservations, DateTime now) {
  final groups = {for (final b in ReservationBucket.values) b: <Reservation>[]};
  for (final r in reservations) {
    groups[bucketOf(r, now)]!.add(r);
  }
  for (final entry in groups.entries) {
    entry.value.sort((a, b) => entry.key == ReservationBucket.pickedUp
        ? b.pickupDate.compareTo(a.pickupDate)
        : a.pickupDate.compareTo(b.pickupDate));
  }
  groups.removeWhere((_, list) => list.isEmpty);
  return groups;
}
