import 'package:skirt_tee_studio/domain/entities/reservation.dart';
import 'package:skirt_tee_studio/domain/repositories/reservation_repository.dart';

class FakeReservationRepository implements ReservationRepository {
  final List<Reservation> _reservations = [];

  @override
  Future<List<Reservation>> getAll() async => List.unmodifiable(_reservations);

  @override
  Future<void> add(Reservation reservation) async => _reservations.add(reservation);

  @override
  Future<void> update(Reservation reservation) async {
    final index = _reservations.indexWhere((r) => r.id == reservation.id);
    _reservations[index] = reservation;
  }

  @override
  Future<void> delete(String id) async => _reservations.removeWhere((r) => r.id == id);
}
