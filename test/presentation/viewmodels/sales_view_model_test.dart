import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/domain/entities/sale.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/sales_view_model.dart';

import '../../fakes/fake_sale_repository.dart';

void main() {
  late FakeSaleRepository repository;
  late SalesViewModel viewModel;

  setUp(() {
    repository = FakeSaleRepository();
    viewModel = SalesViewModel(repository);
  });

  final earlierSale = Sale(
    id: 'sale-1',
    dateTime: DateTime(2026, 1, 1),
    lineItems: const [
      SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 1),
    ],
  );
  final laterSale = Sale(
    id: 'sale-2',
    dateTime: DateTime(2026, 1, 2),
    lineItems: const [
      SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 2),
    ],
  );

  test('load sorts sales newest first', () async {
    await repository.recordSale(earlierSale);
    await repository.recordSale(laterSale);

    await viewModel.load();

    expect(viewModel.sales.map((s) => s.id).toList(), ['sale-2', 'sale-1']);
  });

  test('totalRevenue and totalItemsSold aggregate across sales', () async {
    await repository.recordSale(earlierSale);
    await repository.recordSale(laterSale);

    await viewModel.load();

    expect(viewModel.totalRevenue, 597); // 199 + (199*2)
    expect(viewModel.totalItemsSold, 3);
  });

  test('voidSale removes it via the repository and reloads', () async {
    await repository.recordSale(earlierSale);
    await repository.recordSale(laterSale);
    await viewModel.load();

    await viewModel.voidSale(laterSale);

    expect(repository.voidedSaleIds, ['sale-2']);
    expect(viewModel.sales.map((s) => s.id).toList(), ['sale-1']);
  });
}
