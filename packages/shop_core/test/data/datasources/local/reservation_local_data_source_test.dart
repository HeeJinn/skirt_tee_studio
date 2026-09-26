import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/data/datasources/local/reservation_local_data_source.dart';
import 'package:shop_core/data/models/reservation_model.dart';
import 'package:shop_core/domain/entities/reservation.dart';

import '../../../test_helpers.dart';

void main() {
  late ReservationLocalDataSourceImpl dataSource;

  setUp(() async {
    dataSource = ReservationLocalDataSourceImpl(await openTestDatabase());
  });

  ReservationModel buildReservation({ReservationStatus status = ReservationStatus.pending}) {
    return ReservationModel(
      id: '1',
      customerName: 'Maria',
      contact: '0917 000 0000',
      itemId: 'item-1',
      itemName: 'Basic Tee',
      pickupDate: DateTime(2026, 2, 1),
      status: status,
    );
  }

  test('insert then getAll returns the reservation', () async {
    await dataSource.insert(buildReservation());

    final all = await dataSource.getAll();
    expect(all.single.customerName, 'Maria');
    expect(all.single.status, ReservationStatus.pending);
  });

  test('update marks it picked up', () async {
    await dataSource.insert(buildReservation());
    await dataSource.update(buildReservation(status: ReservationStatus.pickedUp));

    final all = await dataSource.getAll();
    expect(all.single.status, ReservationStatus.pickedUp);
  });

  test('delete removes the reservation', () async {
    await dataSource.insert(buildReservation());
    await dataSource.delete('1');

    expect(await dataSource.getAll(), isEmpty);
  });
}
