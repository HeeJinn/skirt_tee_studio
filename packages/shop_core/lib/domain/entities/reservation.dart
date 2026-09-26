enum ReservationStatus { pending, pickedUp }

/// An online (FB/chat) reservation. Logged manually by staff per the
/// interview ("itatanong kung kailan kukunin").
class Reservation {
  const Reservation({
    required this.id,
    required this.customerName,
    required this.contact,
    required this.itemId,
    required this.itemName,
    required this.pickupDate,
    this.status = ReservationStatus.pending,
  });

  final String id;
  final String customerName;
  final String contact;
  final String itemId;
  final String itemName;
  final DateTime pickupDate;
  final ReservationStatus status;

  Reservation copyWith({ReservationStatus? status}) => Reservation(
        id: id,
        customerName: customerName,
        contact: contact,
        itemId: itemId,
        itemName: itemName,
        pickupDate: pickupDate,
        status: status ?? this.status,
      );
}
