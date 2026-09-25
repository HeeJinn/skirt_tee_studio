// Widget-level smoke test for ReportsScreen. The pure aggregation math is
// covered in report_calculations_test.dart; this exists because fl_chart's
// own layout (axis callbacks, interval math) can throw at render time in
// ways a pure-function test won't catch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skirt_tee_studio/core/theme/app_theme.dart';
import 'package:skirt_tee_studio/domain/entities/item.dart';
import 'package:skirt_tee_studio/domain/entities/sale.dart';
import 'package:skirt_tee_studio/presentation/screens/reports/reports_screen.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/inventory_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/sales_view_model.dart';

import '../../../fakes/fake_item_repository.dart';
import '../../../fakes/fake_stock_repository.dart';
import '../../../fakes/fake_sale_repository.dart';

Widget _buildApp({required bool withSales}) {
  final inventoryViewModel = InventoryViewModel(FakeItemRepository(), FakeStockRepository())
    ..addItem(const Item(id: 'i1', name: 'Basic Tee', category: 'T-Shirt', unitPrice: 199, qtyOnHand: 10))
    ..addItem(const Item(id: 'i2', name: 'Denim Skirt', category: 'Skirt', unitPrice: 399, qtyOnHand: 5));

  final saleRepository = FakeSaleRepository();
  if (withSales) {
    saleRepository.recordSale(Sale(
      id: 'sale-1',
      dateTime: DateTime.now(),
      lineItems: const [
        SaleLineItem(itemId: 'i1', itemName: 'Basic Tee', unitPrice: 199, qty: 3),
        SaleLineItem(itemId: 'i2', itemName: 'Denim Skirt', unitPrice: 399, qty: 1),
      ],
    ));
  }
  final salesViewModel = SalesViewModel(saleRepository);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: inventoryViewModel),
      ChangeNotifierProvider(create: (_) => salesViewModel..load()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: ReportsScreen())),
  );
}

void main() {
  testWidgets('renders all three charts with seeded sales, no layout exceptions', (tester) async {
    await tester.pumpWidget(_buildApp(withSales: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('REVENUE TREND'), findsOneWidget);
    expect(find.text('TOP SELLERS'), findsOneWidget);
    expect(find.text('REVENUE BY CATEGORY'), findsOneWidget);
  });

  testWidgets('switching date range chips does not throw', (tester) async {
    await tester.pumpWidget(_buildApp(withSales: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('7 DAYS'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ALL TIME'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty state instead of charts when there are no sales', (tester) async {
    await tester.pumpWidget(_buildApp(withSales: false));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No sales in this range'), findsOneWidget);
    expect(find.text('REVENUE TREND'), findsNothing);
  });
}
