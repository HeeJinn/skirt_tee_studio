import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:skirt_tee_studio/presentation/screens/sales/sales_history_screen.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/sales_view_model.dart';

import 'package:shop_core/testing/fake_sale_repository.dart';

void main() {
  testWidgets('range, payment, and search filters narrow the list', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    Sale sale(String id, String item, PaymentMethod method, {int daysAgo = 0}) => Sale(
          id: id,
          dateTime: now.subtract(Duration(days: daysAgo)),
          paymentMethod: method,
          lineItems: [SaleLineItem(itemId: id, itemName: item, unitPrice: 100, qty: 1)],
        );

    final repo = FakeSaleRepository();
    await repo.recordSale(sale('a', 'Linen Shorts', PaymentMethod.cash));
    await repo.recordSale(sale('b', 'Denim Skirt', PaymentMethod.gcash));
    await repo.recordSale(sale('c', 'Old Blouse', PaymentMethod.cash, daysAgo: 3));
    final sales = SalesViewModel(repo);
    await sales.load();

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: sales,
      child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SalesHistoryScreen())),
    ));
    await tester.pumpAndSettle();

    // Defaults to Today: the 3-day-old sale is hidden.
    expect(find.text('Linen Shorts'), findsOneWidget);
    expect(find.text('Denim Skirt'), findsOneWidget);
    expect(find.text('Old Blouse'), findsNothing);

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(find.text('Old Blouse'), findsOneWidget);

    await tester.tap(find.byType(DropdownMenu<PaymentMethod?>));
    await tester.pumpAndSettle();
    // Not find.text('GCash'): each sale row also shows its method label.
    // .last: DropdownMenu keeps an offstage copy of its entries for sizing.
    await tester.tap(find.widgetWithText(MenuItemButton, 'GCash').last);
    await tester.pumpAndSettle();
    expect(find.text('Denim Skirt'), findsOneWidget);
    expect(find.text('Linen Shorts'), findsNothing);
    expect(find.text('Old Blouse'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'linen');
    await tester.pumpAndSettle();
    expect(find.text('No sales match these filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
