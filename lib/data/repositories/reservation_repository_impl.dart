import '../../domain/entities/reservation.dart';
import '../../domain/repositories/reservation_repository.dart';
import '../datasources/local/reservation_local_data_source.dart';
import '../models/reservation_model.dart';

class ReservationRepositoryImpl implements ReservationRepository {
  ReservationRepositoryImpl(this._localDataSource);
  final ReservationLocalDataSource _localDataSource;

  @override
  Future<List<Reservation>> getAll() => _localDataSource.getAll();

  @override
  Future<void> add(Reservation reservation) =>
      _localDataSource.insert(ReservationModel.fromEntity(reservation));

  @override
  Future<void> update(Reservation reservation) =>
      _localDataSource.update(ReservationModel.fromEntity(reservation));

  @override
  Future<void> delete(String id) => _localDataSource.delete(id);
}
