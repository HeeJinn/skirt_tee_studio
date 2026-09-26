import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/reservation_view_model.dart';

import '../../fakes/fake_reservation_repository.dart';
import '../../fakes/fake_sale_repository.dart';

void main() {
  late FakeReservationRepository repository;
  late FakeSaleRepository saleRepository;
  late ReservationViewModel viewModel;

  setUp(() {
    repository = FakeReservationRepository();
    saleRepository = FakeSaleRepository();
    viewModel = ReservationViewModel(repository, saleRepository);
  });

  final reservation = Reservation(
    id: '1',
    customerName: 'Maria',
    contact: '0917 000 0000',
    itemId: 'item-1',
    itemName: 'Basic Tee',
    pickupDate: DateTime(2026, 2, 1),
  );

  const item = Item(
    id: 'item-1',
    name: 'Basic Tee',
    category: 'T-Shirt',
    unitPrice: 199,
    qtyOnHand: 3,
  );

  test('addReservation persists then reloads the list', () async {
    await viewModel.addReservation(reservation);

    expect(viewModel.reservations, [reservation]);
  });

  test('markPickedUp flips status without mutating the caller\'s copy', () async {
    await viewModel.addReservation(reservation);
    await viewModel.markPickedUp(reservation);

    expect(reservation.status, ReservationStatus.pending);
    expect(viewModel.reservations.single.status, ReservationStatus.pickedUp);
  });

  test('updateReservation persists the full edited record', () async {
    await viewModel.addReservation(reservation);

    final edited = Reservation(
      id: reservation.id,
      customerName: 'Maria Updated',
      contact: '0917 111 1111',
      itemId: reservation.itemId,
      itemName: reservation.itemName,
      pickupDate: DateTime(2026, 3, 1),
    );
    await viewModel.updateReservation(edited);

    expect(viewModel.reservations.single.customerName, 'Maria Updated');
    expect(viewModel.reservations.single.contact, '0917 111 1111');
    expect(viewModel.reservations.single.pickupDate, DateTime(2026, 3, 1));
  });

  test('deleteReservation removes it from the list', () async {
    await viewModel.addReservation(reservation);
    await viewModel.deleteReservation(reservation.id);

    expect(viewModel.reservations, isEmpty);
  });

  test('completePickup records a sale, deducts via the sale repository, and flips status', () async {
    await viewModel.addReservation(reservation);

    await viewModel.completePickup(reservation, const [item], PaymentMethod.cash);

    expect(viewModel.reservations.single.status, ReservationStatus.pickedUp);
    expect(saleRepository.lastRecordedSale, isNotNull);
    expect(saleRepository.lastRecordedSale!.lineItems.single.itemId, 'item-1');
    expect(saleRepository.lastRecordedSale!.lineItems.single.qty, 1);
    expect(saleRepository.lastRecordedSale!.totalAmount, 199);
    expect(saleRepository.lastRecordedSale!.paymentMethod, PaymentMethod.cash);
  });

  test('completePickup throws and leaves state untouched when the item is gone', () async {
    await viewModel.addReservation(reservation);

    await expectLater(
      () => viewModel.completePickup(reservation, const [], PaymentMethod.cash),
      throwsA(isA<PickupBlockedException>()),
    );
    expect(viewModel.reservations.single.status, ReservationStatus.pending);
    expect(saleRepository.lastRecordedSale, isNull);
  });

  test('completePickup throws and leaves state untouched when out of stock', () async {
    await viewModel.addReservation(reservation);
    const outOfStock = Item(
      id: 'item-1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 0,
    );

    await expectLater(
      () => viewModel.completePickup(reservation, const [outOfStock], PaymentMethod.cash),
      throwsA(isA<PickupBlockedException>()),
    );
    expect(viewModel.reservations.single.status, ReservationStatus.pending);
    expect(saleRepository.lastRecordedSale, isNull);
  });
}
