import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/repositories/sale_repository.dart';

/// One item + quantity in the cart being built on the POS screen.
/// Session-only state — never persisted directly, only via the Sale it
/// produces at checkout.
class CartLine {
  CartLine({required this.item, required this.qty});
  final Item item;
  int qty;

  double get subtotal => item.sellingPrice * qty;
}

class CartViewModel extends ChangeNotifier {
  CartViewModel(this._repository);
  final SaleRepository _repository;
  static const _uuid = Uuid();

  final List<CartLine> _lines = [];
  List<CartLine> get lines => List.unmodifiable(_lines);

  double get total => _lines.fold(0, (sum, l) => sum + l.subtotal);
  int get itemCount => _lines.fold(0, (sum, l) => sum + l.qty);
  bool get isEmpty => _lines.isEmpty;

  int qtyInCart(String itemId) =>
      _lines.where((l) => l.item.id == itemId).fold(0, (sum, l) => sum + l.qty);

  CartLine? _findLine(String itemId) =>
      _lines.cast<CartLine?>().firstWhere((l) => l!.item.id == itemId, orElse: () => null);

  /// Adds one unit of [item], capped at its current stock on hand.
  void addItem(Item item) {
    if (qtyInCart(item.id) >= item.qtyOnHand) return;

    final existing = _findLine(item.id);
    if (existing != null) {
      existing.qty++;
    } else {
      _lines.add(CartLine(item: item, qty: 1));
    }
    notifyListeners();
  }

  void decrementItem(String itemId) {
    final existing = _findLine(itemId);
    if (existing == null) return;
    if (existing.qty <= 1) {
      _lines.removeWhere((l) => l.item.id == itemId);
    } else {
      existing.qty--;
    }
    notifyListeners();
  }

  void removeItem(String itemId) {
    _lines.removeWhere((l) => l.item.id == itemId);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  /// Completes the sale: writes the Sale record and deducts stock.
  /// [amountTendered] is the cash handed over, for cash sales.
  /// Returns false (leaving the cart untouched) if it's empty.
  Future<bool> checkout(PaymentMethod paymentMethod, {double? amountTendered}) async {
    if (_lines.isEmpty) return false;
    final sale = Sale(
      id: _uuid.v4(),
      dateTime: DateTime.now(),
      paymentMethod: paymentMethod,
      amountTendered: amountTendered,
      lineItems: _lines
          .map((l) => SaleLineItem(
                itemId: l.item.id,
                itemName: l.item.name,
                unitPrice: l.item.sellingPrice,
                qty: l.qty,
              ))
          .toList(),
    );
    await _repository.recordSale(sale);
    clear();
    return true;
  }
}
