import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/repositories/reservation_repository.dart';
import 'package:shop_core/domain/repositories/sale_repository.dart';

/// Thrown by [ReservationViewModel.completePickup] when the reserved item
/// can't be sold as-is (deleted, or out of stock) — callers show this
/// message rather than the pickup silently deducting negative stock.
class PickupBlockedException implements Exception {
  PickupBlockedException(this.message);
  final String message;
}

class ReservationViewModel extends ChangeNotifier {
  ReservationViewModel(this._repository, this._saleRepository);
  final ReservationRepository _repository;
  final SaleRepository _saleRepository;
  static const _uuid = Uuid();

  List<Reservation> _reservations = [];
  List<Reservation> get reservations => List.unmodifiable(_reservations);

  Future<void> load() async {
    _reservations = await _repository.getAll();
    notifyListeners();
  }

  Future<void> addReservation(Reservation reservation) async {
    await _repository.add(reservation);
    await load();
  }

  Future<void> updateReservation(Reservation reservation) async {
    await _repository.update(reservation);
    await load();
  }

  Future<void> markPickedUp(Reservation reservation) async {
    await _repository.update(reservation.copyWith(status: ReservationStatus.pickedUp));
    await load();
  }

  Future<void> deleteReservation(String id) async {
    await _repository.delete(id);
    await load();
  }

  /// Completes a pickup *as a sale*: deducts stock for the reserved item
  /// (looked up from [inventory], the caller's live snapshot) and records a
  /// Sale the same way POS checkout does, then flips the reservation to
  /// picked up. Reserving doesn't hold stock aside, so this re-checks
  /// availability at pickup time instead of trusting the reservation.
  /// [amountTendered] is the cash handed over, for cash pickups.
  Future<void> completePickup(
    Reservation reservation,
    List<Item> inventory,
    PaymentMethod paymentMethod, {
    double? amountTendered,
  }) async {
    Item? item;
    for (final candidate in inventory) {
      if (candidate.id == reservation.itemId) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      throw PickupBlockedException(
        '"${reservation.itemName}" is no longer in inventory — edit or cancel this reservation instead.',
      );
    }
    if (item.qtyOnHand < 1) {
      throw PickupBlockedException('"${item.name}" is out of stock — restock before completing this pickup.');
    }

    await _saleRepository.recordSale(Sale(
      id: _uuid.v4(),
      dateTime: DateTime.now(),
      paymentMethod: paymentMethod,
      amountTendered: amountTendered,
      lineItems: [
        SaleLineItem(itemId: item.id, itemName: item.name, unitPrice: item.unitPrice, qty: 1),
      ],
    ));
    await _repository.update(reservation.copyWith(status: ReservationStatus.pickedUp));
    await load();
  }
}
