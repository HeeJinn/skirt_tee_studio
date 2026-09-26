import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import 'package:shop_core/calculations/reservation_grouping.dart';

void main() {
  final now = DateTime(2026, 3, 10, 15, 30);

  Reservation reservation(String id, DateTime pickup, {ReservationStatus status = ReservationStatus.pending}) =>
      Reservation(
        id: id,
        customerName: 'Maria',
        contact: 'fb:maria',
        itemId: 'i1',
        itemName: 'Basic Tee',
        pickupDate: pickup,
        status: status,
      );

  group('bucketOf', () {
    test('pending in the past is overdue, by calendar day not by hour', () {
      expect(bucketOf(reservation('1', DateTime(2026, 3, 9, 23, 59)), now), ReservationBucket.overdue);
    });

    test('pending earlier today is still today, not overdue', () {
      expect(bucketOf(reservation('1', DateTime(2026, 3, 10, 8)), now), ReservationBucket.today);
    });

    test('pending in the future is upcoming', () {
      expect(bucketOf(reservation('1', DateTime(2026, 3, 11)), now), ReservationBucket.upcoming);
    });

    test('picked up wins regardless of date', () {
      final r = reservation('1', DateTime(2026, 3, 1), status: ReservationStatus.pickedUp);
      expect(bucketOf(r, now), ReservationBucket.pickedUp);
    });
  });

  group('relativePickupLabel', () {
    test('covers overdue, today, tomorrow, and further out', () {
      expect(relativePickupLabel(DateTime(2026, 3, 9), now), '1 day overdue');
      expect(relativePickupLabel(DateTime(2026, 3, 7), now), '3 days overdue');
      expect(relativePickupLabel(DateTime(2026, 3, 10), now), 'Today');
      expect(relativePickupLabel(DateTime(2026, 3, 11), now), 'Tomorrow');
      expect(relativePickupLabel(DateTime(2026, 3, 14), now), 'In 4 days');
    });
  });

  group('groupReservations', () {
    test('drops empty buckets and keeps display order', () {
      final groups = groupReservations([
        reservation('up', DateTime(2026, 3, 12)),
        reservation('late', DateTime(2026, 3, 8)),
      ], now);

      expect(groups.keys.toList(), [ReservationBucket.overdue, ReservationBucket.upcoming]);
    });

    test('sorts overdue oldest-first and picked-up newest-first', () {
      final groups = groupReservations([
        reservation('late-1', DateTime(2026, 3, 8)),
        reservation('late-2', DateTime(2026, 3, 5)),
        reservation('done-1', DateTime(2026, 3, 1), status: ReservationStatus.pickedUp),
        reservation('done-2', DateTime(2026, 3, 4), status: ReservationStatus.pickedUp),
      ], now);

      expect(groups[ReservationBucket.overdue]!.map((r) => r.id), ['late-2', 'late-1']);
      expect(groups[ReservationBucket.pickedUp]!.map((r) => r.id), ['done-2', 'done-1']);
    });
  });
}
