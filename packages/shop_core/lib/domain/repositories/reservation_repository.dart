import '../entities/reservation.dart';

abstract class ReservationRepository {
  Future<List<Reservation>> getAll();
  Future<void> add(Reservation reservation);
  Future<void> update(Reservation reservation);
  Future<void> delete(String id);
}
