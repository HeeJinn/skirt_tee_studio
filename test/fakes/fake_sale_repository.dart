import 'package:skirt_tee_studio/domain/entities/sale.dart';
import 'package:skirt_tee_studio/domain/repositories/sale_repository.dart';

class FakeSaleRepository implements SaleRepository {
  Sale? lastRecordedSale;
  final List<Sale> _sales = [];
  final List<String> voidedSaleIds = [];

  @override
  Future<void> recordSale(Sale sale) async {
    lastRecordedSale = sale;
    _sales.add(sale);
  }

  @override
  Future<List<Sale>> getAll() async => List.unmodifiable(_sales);

  @override
  Future<void> voidSale(String id) async {
    voidedSaleIds.add(id);
    _sales.removeWhere((s) => s.id == id);
  }
}
