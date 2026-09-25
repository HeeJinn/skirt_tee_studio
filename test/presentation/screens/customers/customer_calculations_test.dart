import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/domain/entities/reservation.dart';
import 'package:skirt_tee_studio/presentation/screens/customers/customer_calculations.dart';

void main() {
  Reservation reservation({
    required String id,
    required String customerName,
    required String contact,
    required DateTime pickupDate,
    ReservationStatus status = ReservationStatus.pending,
  }) =>
      Reservation(
        id: id,
        customerName: customerName,
        contact: contact,
        itemId: 'item-1',
        itemName: 'Basic Tee',
        pickupDate: pickupDate,
        status: status,
      );

  test('groups reservations sharing a contact into one customer', () {
    final reservations = [
      reservation(id: '1', customerName: 'Maria', contact: '0917 000 0000', pickupDate: DateTime(2026, 1, 1)),
      reservation(id: '2', customerName: 'Maria', contact: '0917 000 0000', pickupDate: DateTime(2026, 2, 1)),
    ];

    final summaries = groupByCustomer(reservations);

    expect(summaries, hasLength(1));
    expect(summaries.single.totalReservations, 2);
  });

  test('groups by contact case/whitespace-insensitively', () {
    final reservations = [
      reservation(id: '1', customerName: 'Maria', contact: ' 0917-000-0000 ', pickupDate: DateTime(2026, 1, 1)),
      reservation(id: '2', customerName: 'Maria S.', contact: '0917-000-0000', pickupDate: DateTime(2026, 2, 1)),
    ];

    final summaries = groupByCustomer(reservations);

    expect(summaries, hasLength(1));
  });

  test('different contacts stay separate customers even with the same name', () {
    final reservations = [
      reservation(id: '1', customerName: 'Maria', contact: '0917 000 0000', pickupDate: DateTime(2026, 1, 1)),
      reservation(id: '2', customerName: 'Maria', contact: '0918 111 1111', pickupDate: DateTime(2026, 1, 2)),
    ];

    expect(groupByCustomer(reservations), hasLength(2));
  });

  test('customerName reflects the most recent reservation, not the first', () {
    final reservations = [
      reservation(id: '1', customerName: 'Maria Cruz', contact: 'fb:maria', pickupDate: DateTime(2026, 1, 1)),
      reservation(id: '2', customerName: 'Maria C.', contact: 'fb:maria', pickupDate: DateTime(2026, 3, 1)),
    ];

    final summary = groupByCustomer(reservations).single;

    expect(summary.customerName, 'Maria C.');
    expect(summary.lastActivity, DateTime(2026, 3, 1));
  });

  test('reservations within a customer are sorted newest first', () {
    final reservations = [
      reservation(id: '1', customerName: 'Maria', contact: 'fb:maria', pickupDate: DateTime(2026, 1, 1)),
      reservation(id: '2', customerName: 'Maria', contact: 'fb:maria', pickupDate: DateTime(2026, 3, 1)),
      reservation(id: '3', customerName: 'Maria', contact: 'fb:maria', pickupDate: DateTime(2026, 2, 1)),
    ];

    final summary = groupByCustomer(reservations).single;

    expect(summary.reservations.map((r) => r.id).toList(), ['2', '3', '1']);
  });

  test('pickedUpCount only counts picked-up reservations', () {
    final reservations = [
      reservation(
        id: '1',
        customerName: 'Maria',
        contact: 'fb:maria',
        pickupDate: DateTime(2026, 1, 1),
        status: ReservationStatus.pickedUp,
      ),
      reservation(id: '2', customerName: 'Maria', contact: 'fb:maria', pickupDate: DateTime(2026, 2, 1)),
    ];

    expect(groupByCustomer(reservations).single.pickedUpCount, 1);
  });

  test('customers are ordered by most recent activity first', () {
    final reservations = [
      reservation(id: '1', customerName: 'Ana', contact: 'fb:ana', pickupDate: DateTime(2026, 1, 1)),
      reservation(id: '2', customerName: 'Bea', contact: 'fb:bea', pickupDate: DateTime(2026, 3, 1)),
    ];

    final summaries = groupByCustomer(reservations);

    expect(summaries.map((s) => s.customerName).toList(), ['Bea', 'Ana']);
  });

  test('empty input yields no customers', () {
    expect(groupByCustomer(const []), isEmpty);
  });
}
