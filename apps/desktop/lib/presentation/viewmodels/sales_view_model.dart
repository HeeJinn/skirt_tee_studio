import 'package:flutter/foundation.dart';

import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/repositories/sale_repository.dart';

class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this._repository);
  final SaleRepository _repository;

  List<Sale> _sales = [];
  List<Sale> get sales => List.unmodifiable(_sales);

  double get totalRevenue => _sales.fold(0, (sum, s) => sum + s.totalAmount);
  int get totalItemsSold => _sales.fold(0, (sum, s) => sum + s.totalItemsSold);

  Future<void> load() async {
    final all = await _repository.getAll();
    _sales = all.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    notifyListeners();
  }

  /// Records a sale made outside the POS cart flow (e.g. a reservation
  /// pickup) — deducts stock the same way checkout does.
  Future<void> recordSale(Sale sale) async {
    await _repository.recordSale(sale);
    await load();
  }

  /// Restores stock and removes the sale. Callers also need to reload
  /// InventoryViewModel since this changes stock outside its own view.
  Future<void> voidSale(Sale sale) async {
    await _repository.voidSale(sale.id);
    await load();
  }
}
