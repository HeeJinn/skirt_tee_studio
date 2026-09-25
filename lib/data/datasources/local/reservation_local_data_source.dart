import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/reservation_model.dart';

abstract class ReservationLocalDataSource {
  Future<List<ReservationModel>> getAll();
  Future<void> insert(ReservationModel model);
  Future<void> update(ReservationModel model);
  Future<void> delete(String id);
}

class ReservationLocalDataSourceImpl implements ReservationLocalDataSource {
  ReservationLocalDataSourceImpl(this._db);
  final Database _db;

  @override
  Future<List<ReservationModel>> getAll() async {
    final rows = await _db.query('reservations', orderBy: 'pickupDate');
    return rows.map(ReservationModel.fromMap).toList();
  }

  @override
  Future<void> insert(ReservationModel model) =>
      _db.insert('reservations', model.toMap());

  @override
  Future<void> update(ReservationModel model) => _db.update(
        'reservations',
        model.toMap(),
        where: 'id = ?',
        whereArgs: [model.id],
      );

  @override
  Future<void> delete(String id) => _db.delete(
        'reservations',
        where: 'id = ?',
        whereArgs: [id],
      );
}
