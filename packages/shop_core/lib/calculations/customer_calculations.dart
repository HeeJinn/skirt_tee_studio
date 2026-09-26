import '../domain/entities/reservation.dart';

/// A customer isn't its own stored entity — it's derived by grouping
/// reservations that share a contact. Contact (phone/FB), not name, is the
/// grouping key: it's a required field on every reservation and a more
/// stable identifier than a hand-typed name, which can vary in spelling
/// across visits.
class CustomerSummary {
  const CustomerSummary({
    required this.customerName,
    required this.contact,
    required this.reservations,
  });

  /// Most recent reservation's spelling — the freshest data staff entered.
  final String customerName;
  final String contact;

  /// Newest first.
  final List<Reservation> reservations;

  int get totalReservations => reservations.length;
  int get pickedUpCount => reservations.where((r) => r.status == ReservationStatus.pickedUp).length;
  DateTime get lastActivity => reservations.first.pickupDate;
}

/// Groups reservations by contact, newest-activity-first.
List<CustomerSummary> groupByCustomer(List<Reservation> reservations) {
  final byContact = <String, List<Reservation>>{};
  for (final r in reservations) {
    final key = r.contact.trim().toLowerCase();
    byContact.putIfAbsent(key, () => []).add(r);
  }

  final summaries = byContact.values.map((forCustomer) {
    final sorted = forCustomer.toList()..sort((a, b) => b.pickupDate.compareTo(a.pickupDate));
    return CustomerSummary(
      customerName: sorted.first.customerName,
      contact: sorted.first.contact,
      reservations: sorted,
    );
  }).toList();

  summaries.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  return summaries;
}
