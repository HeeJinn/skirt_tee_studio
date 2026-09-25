import '../../domain/entities/reservation.dart';

class ReservationModel extends Reservation {
  const ReservationModel({
    required super.id,
    required super.customerName,
    required super.contact,
    required super.itemId,
    required super.itemName,
    required super.pickupDate,
    super.status,
  });

  factory ReservationModel.fromEntity(Reservation reservation) => ReservationModel(
        id: reservation.id,
        customerName: reservation.customerName,
        contact: reservation.contact,
        itemId: reservation.itemId,
        itemName: reservation.itemName,
        pickupDate: reservation.pickupDate,
        status: reservation.status,
      );

  factory ReservationModel.fromMap(Map<String, dynamic> map) => ReservationModel(
        id: map['id'] as String,
        customerName: map['customerName'] as String,
        contact: map['contact'] as String,
        itemId: map['itemId'] as String,
        itemName: map['itemName'] as String,
        pickupDate: DateTime.parse(map['pickupDate'] as String),
        status: ReservationStatus.values.byName(map['status'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerName': customerName,
        'contact': contact,
        'itemId': itemId,
        'itemName': itemName,
        'pickupDate': pickupDate.toIso8601String(),
        'status': status.name,
      };
}
