// The app with a fake cloud connection and a seeded shop: signing in, the
// tabs, and signing out.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/app.dart';
import 'package:owner_mobile/core/period.dart';
import 'package:owner_mobile/presentation/screens/more/more_screen.dart';
import 'package:owner_mobile/presentation/viewmodels/money_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/sales_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/stock_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/today_view_model.dart';
import 'package:owner_mobile/presentation/widgets/ui/section.dart';
import 'package:owner_mobile/presentation/widgets/ui/segmented_control.dart';
import 'package:owner_mobile/presentation/widgets/ui/shop_tab_bar.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:shop_core/testing/fake_cloud_sync_repository.dart';
import 'package:shop_core/testing/fake_item_repository.dart';
import 'package:shop_core/testing/fake_money_repository.dart';
import 'package:shop_core/testing/fake_reservation_repository.dart';
import 'package:shop_core/testing/fake_sale_repository.dart';
import 'package:shop_core/testing/fake_settings_repository.dart';
import 'package:shop_core/testing/fake_stock_repository.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

/// A Saturday at the shop: two sales so far, one of them bigger than last
/// Saturday's only sale, a mixed GCash sale on Tuesday (one piece with no
/// recorded cost), and a tee that's sold out.
final _now = DateTime(2026, 9, 26, 15);

late FakeSaleRepository _saleRepo;
late SalesViewModel _salesVm;

Future<(TodayViewModel, SalesViewModel, StockViewModel, MoneyViewModel)> _seededShop() async {
  final sales = _saleRepo = FakeSaleRepository();
  final items = FakeItemRepository();
  Sale sale(String id, DateTime at, double price, int qty, {double? tendered}) => Sale(
        id: id,
        dateTime: at,
        paymentMethod: PaymentMethod.cash,
        amountTendered: tendered,
        lineItems: [SaleLineItem(itemId: 'skirt', itemName: 'Pleated skirt', unitPrice: price, qty: qty, unitCost: 200)],
      );
  await sales.recordSale(sale('a', DateTime(2026, 9, 26, 10, 5), 450, 2, tendered: 1000));
  await sales.recordSale(sale('b', DateTime(2026, 9, 26, 14, 41), 450, 1));
  await sales.recordSale(sale('c', DateTime(2026, 9, 19, 11), 450, 2));
  await sales.recordSale(Sale(
    id: 'd',
    dateTime: DateTime(2026, 9, 22, 16, 30),
    paymentMethod: PaymentMethod.gcash,
    lineItems: const [
      SaleLineItem(itemId: 'tee', itemName: 'Basic tee', unitPrice: 150, qty: 2, unitCost: 90),
      SaleLineItem(itemId: 'old', itemName: 'Vintage blouse', unitPrice: 300, qty: 1),
    ],
  ));
  await items.add(const Item(id: 'tee', name: 'Basic tee', category: 'T-Shirt', unitPrice: 150, qtyOnHand: 0));
  await items.add(
    const Item(id: 'skirt', name: 'Pleated skirt', category: 'Skirt', unitPrice: 450, qtyOnHand: 12, unitCost: 200),
  );
  await items.add(const Item(id: 'dress', name: 'Floral dress', category: 'Dress', unitPrice: 600, qtyOnHand: 3));
  final stock = FakeStockRepository(items);
  stock.lots.add(StockLot(id: 'lot-1', at: DateTime(2026, 9, 20, 9), supplier: 'Divisoria bale', itemsCost: 2800));
  stock.movements.addAll([
    StockMovement(
      at: DateTime(2026, 9, 20, 9),
      itemId: 'skirt',
      itemName: 'Pleated skirt',
      type: StockMovementType.received,
      qty: 14,
      unitCost: 200,
      lotId: 'lot-1',
    ),
    StockMovement(
      at: DateTime(2026, 9, 23, 17),
      itemId: 'skirt',
      itemName: 'Pleated skirt',
      type: StockMovementType.writeOff,
      qty: 1,
      unitCost: 200,
      reason: WriteOffReason.damaged,
      note: 'Torn hem',
    ),
  ]);
  final settings = FakeSettingsRepository();
  final today = TodayViewModel(sales, items, FakeReservationRepository(), settings, clock: () => _now);
  final salesVm = _salesVm = SalesViewModel(sales, clock: () => _now);
  final stockVm = StockViewModel(items, stock, sales, settings, clock: () => _now);
  // The books started on the 1st, when Ana put in the first ten thousand.
  final money = FakeMoneyRepository(booksStartedAt: DateTime(2026, 9, 1));
  await money.add(MoneyEntry(
    id: 'in',
    at: DateTime(2026, 9, 1, 9),
    kind: MoneyEntryKind.capitalIn,
    amount: 10000,
    paidFrom: PaidFrom.owners,
    person: 'Ana',
  ));
  await money.add(MoneyEntry(
    id: 'rent',
    at: DateTime(2026, 9, 5, 9),
    kind: MoneyEntryKind.expense,
    amount: 1000,
    category: ExpenseCategory.rent,
  ));
  await money.add(MoneyEntry(id: 'home', at: DateTime(2026, 9, 10, 9), kind: MoneyEntryKind.ownerDraw, amount: 1000));
  final moneyVm = MoneyViewModel(money, sales, stock, items, clock: () => _now);
  await Future.wait([today.load(), salesVm.load(), stockVm.load(), moneyVm.load()]);
  return (today, salesVm, stockVm, moneyVm);
}

/// Pumps the app at an iPhone 15's screen size, or [size].
Future<FakeCloudSyncRepository> _pumpApp(
  WidgetTester tester, {
  CloudSyncState? initial,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final cloud = FakeCloudSyncRepository(initial: initial ?? CloudSyncState.signedOut);
  final sync = CloudSyncViewModel(cloud, onRemoteChanges: () async {});
  await sync.load();
  final (today, sales, stock, money) = await _seededShop();
  await tester.pumpWidget(OwnerApp(cloudSync: sync, today: today, sales: sales, stock: stock, money: money));
  await tester.pumpAndSettle();
  return cloud;
}

const _connected = CloudSyncState(status: CloudStatus.upToDate, email: 'owner@example.com');

void main() {
  /// Email, Continue, then the password and Sign In.
  Future<void> signIn(WidgetTester tester, String password) async {
    await tester.enterText(find.widgetWithText(CupertinoTextField, 'Email'), 'owner@example.com');
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(CupertinoTextField, 'Password'), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Sign In'));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String label) =>
      tester.widget<CupertinoButton>(find.widgetWithText(CupertinoButton, label)).onPressed != null;

  testWidgets('sign-in asks for the email first, then the password', (tester) async {
    await _pumpApp(tester);

    expect(find.widgetWithText(CupertinoTextField, 'Password'), findsNothing);
    expect(enabled(tester, 'Continue'), isFalse, reason: 'nothing to continue with yet');

    await tester.enterText(find.widgetWithText(CupertinoTextField, 'Email'), 'owner@example.com');
    await tester.pump();
    expect(enabled(tester, 'Continue'), isTrue);

    await tester.tap(find.widgetWithText(CupertinoButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CupertinoTextField, 'Password'), findsOneWidget);
    expect(enabled(tester, 'Sign In'), isFalse, reason: 'no password yet');
  });

  testWidgets('signing in with the wrong password shows why and stays on sign-in', (tester) async {
    await _pumpApp(tester);
    await signIn(tester, 'wrong');

    expect(find.text("That email and password don't match."), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-Today')), findsNothing);
  });

  testWidgets("an email that isn't one is caught before asking for the password", (tester) async {
    await _pumpApp(tester);

    await tester.enterText(find.widgetWithText(CupertinoTextField, 'Email'), 'owner');
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text("Enter the account's email."), findsOneWidget);
    expect(find.widgetWithText(CupertinoTextField, 'Password'), findsNothing);
  });

  testWidgets('forgot password says where the login comes from', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Settings → Cloud backup'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('sign-in fits on a small phone', (tester) async {
    await _pumpApp(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a good sign-in opens the five tabs', (tester) async {
    await _pumpApp(tester);
    await signIn(tester, FakeCloudSyncRepository.goodPassword);

    expect(tester.takeException(), isNull);
    for (final tab in ['Today', 'Sales', 'Stock', 'Money', 'More']) {
      expect(find.byKey(ValueKey('tab-$tab')), findsOneWidget, reason: tab);
    }
  });

  testWidgets('each tab opens without layout errors', (tester) async {
    await _pumpApp(tester, initial: _connected);

    for (final tab in ['Sales', 'Stock', 'Money', 'More', 'Today']) {
      await tester.tap(find.byKey(ValueKey('tab-$tab')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('More shows the account, and signing out asks first', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await tester.tap(find.byKey(const ValueKey('tab-More')));
    await tester.pumpAndSettle();
    expect(find.text('owner@example.com'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('owner@example.com'), findsOneWidget, reason: 'cancel keeps you signed in');

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(CupertinoActionSheet), matching: find.text('Sign out')));
    await tester.pumpAndSettle();
    expect(find.textContaining('owner login'), findsOneWidget, reason: 'back on sign-in');
  });

  testWidgets("Today shows the day's numbers against last week, and what needs attention", (tester) async {
    await _pumpApp(tester, initial: _connected);

    expect(find.text('₱1,350'), findsOneWidget, reason: 'sales today');
    expect(find.text('50%'), findsOneWidget, reason: 'sales up by half, in the hero');
    expect(find.text('vs last Saturday · ₱900'), findsOneWidget);
    expect(find.text('↑ 50%'), findsNWidgets(2), reason: 'profit and pieces also rose by half');
    expect(find.text('↑ 100%'), findsOneWidget, reason: 'two sales against one');
    expect(find.text('₱750'), findsOneWidget, reason: 'gross profit: 3 × (₱450 − ₱200)');
    expect(find.text('1 item sold out'), findsOneWidget);
    expect(find.text('Basic tee'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Latest sales'),
      200,
      scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('Pleated skirt ×2'), findsWidgets);
  });

  for (final (name, size) in [('iPhone 15', Size(393, 852)), ('a small phone', Size(320, 568))]) {
    testWidgets('Today fits on $name', (tester) async {
      await _pumpApp(tester, initial: _connected, size: size);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> openSales(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tab-Sales')));
    await tester.pumpAndSettle();
  }

  Future<void> pickKind(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(ShopSegmentedControl<PeriodKind>), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> stepEarlier(WidgetTester tester, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.bySemanticsLabel('Earlier'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets("Sales opens on today's sales, under the day's total", (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);

    expect(find.text('2 sales · 3 pieces · average ₱675'), findsOneWidget);
    expect(find.text('Today, Sep 26'), findsOneWidget);
    expect(find.byType(SectionHeader), findsNothing, reason: 'one day needs no heading of its own');
    expect(find.text('Pleated skirt ×2'), findsOneWidget);
    expect(find.text('Pleated skirt'), findsOneWidget);
    expect(find.text('Basic tee ×2, Vintage blouse'), findsNothing, reason: "Tuesday's sale isn't today");
  });

  testWidgets('stepping back a day shows that day, and the future stays out of reach', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);

    expect(find.text('Today, Sep 26'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Later')), isSemantics(isEnabled: false, hasEnabledState: true));

    await stepEarlier(tester);
    expect(find.text('Yesterday, Sep 25'), findsOneWidget);
    expect(find.text('No sales yesterday.'), findsOneWidget);

    await stepEarlier(tester, times: 3);
    expect(find.text('Tue, Sep 22'), findsWidgets);
    expect(find.text('1 sale · 3 pieces · average ₱600'), findsOneWidget);
    expect(find.text('Basic tee ×2, Vintage blouse'), findsOneWidget);
  });

  testWidgets('a month shows every sale in it, grouped by day, newest first', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);

    await pickKind(tester, 'Month');
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.textContaining('4 sales · 8 pieces'), findsOneWidget);
    expect(find.text('Tue, Sep 22'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sat, Sep 19'),
      200,
      scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('Sat, Sep 19'), findsOneWidget);
  });

  testWidgets('tapping the date opens a wheel to jump to any day', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);
    await stepEarlier(tester);

    await tester.tap(find.bySemanticsLabel('Pick a day'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.widgetWithText(CupertinoButton, 'Today'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
    expect(find.text('Today, Sep 26'), findsOneWidget);
  });

  testWidgets('a sale shows its payment, change, and what the shop made', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);

    await tester.tap(find.text('Pleated skirt ×2'));
    await tester.pumpAndSettle();

    expect(find.text('₱900.00'), findsWidgets);
    expect(find.text('Received'), findsOneWidget, reason: 'cash received');
    expect(find.text('₱1,000.00'), findsOneWidget);
    expect(find.text('₱100.00'), findsOneWidget, reason: 'change');
    expect(find.text('₱500.00'), findsOneWidget, reason: 'gross profit: 2 × (₱450 − ₱200)');
    expect(find.textContaining('reads high'), findsNothing);
  });

  testWidgets('a sale with an uncosted piece says its profit reads high', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);
    await pickKind(tester, 'Month');

    await tester.tap(find.text('Basic tee ×2, Vintage blouse'));
    await tester.pumpAndSettle();

    expect(find.text('GCash'), findsOneWidget);
    expect(find.textContaining('cost not recorded'), findsOneWidget);
    expect(find.textContaining('reads high'), findsOneWidget);
  });

  testWidgets('a sale voided on the shop computer says so instead of showing old figures', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);
    await tester.tap(find.text('Pleated skirt ×2'));
    await tester.pumpAndSettle();

    await _saleRepo.voidSale('a');
    await _salesVm.load();
    await tester.pumpAndSettle();

    expect(find.textContaining('was voided on the shop computer'), findsOneWidget);
  });

  testWidgets('a sale opened from Today goes back to Today', (tester) async {
    await _pumpApp(tester, initial: _connected);
    // Today's sale; last Saturday's has the same summary further down.
    final todaysSale = find.text('Pleated skirt ×2').first;
    final page = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(todaysSale, 200, scrollable: page);
    // Clear the translucent tab bar, which sits over the bottom of the list.
    await tester.drag(page, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(todaysSale);
    await tester.pumpAndSettle();

    final navBar = find.byType(CupertinoNavigationBar);
    expect(find.descendant(of: navBar, matching: find.text('Sale')), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Today'), findsOneWidget, reason: 'the back button');
  });

  testWidgets('Sales and a sale fit on a small phone', (tester) async {
    await _pumpApp(tester, initial: _connected, size: const Size(320, 568));
    await openSales(tester);
    await pickKind(tester, 'Month');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Pleated skirt ×2').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  Future<void> openStock(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tab-Stock')));
    await tester.pumpAndSettle();
  }

  testWidgets('Stock shows every item with how many are left', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openStock(tester);

    expect(find.text('3 items · 15 pieces on hand'), findsOneWidget);
    expect(find.text('Low (1)'), findsOneWidget);
    expect(find.text('Sold out (1)'), findsOneWidget);
    expect(find.text('Basic tee'), findsOneWidget);
    expect(find.text('₱150.00'), findsOneWidget, reason: 'sold out: price only');
    expect(find.text('Sold out'), findsOneWidget, reason: 'the pill on its photo');
    expect(find.text('3 left'), findsOneWidget, reason: 'the low-stock pill');
    expect(find.text('₱600.00 · 3 on hand'), findsOneWidget);
    expect(find.text('₱450.00 · 12 on hand'), findsOneWidget);
  });

  testWidgets('filters and search narrow the grid', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openStock(tester);

    await tester.tap(find.text('Low (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Floral dress'), findsOneWidget);
    expect(find.text('Pleated skirt'), findsNothing);

    await tester.tap(find.text('Sold out (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Basic tee'), findsOneWidget);
    expect(find.text('Floral dress'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(CupertinoSearchTextField), 'skirt');
    await tester.pumpAndSettle();
    expect(find.text('Pleated skirt'), findsOneWidget);
    expect(find.text('Basic tee'), findsNothing);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'hat');
    await tester.pumpAndSettle();
    expect(find.text('No items match "hat".'), findsOneWidget);
  });

  testWidgets('an item shows its price, margin, stock, and history', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openStock(tester);

    await tester.tap(find.text('Pleated skirt'));
    await tester.pumpAndSettle();

    expect(find.text('₱200.00 each'), findsOneWidget);
    expect(find.text('₱250'), findsOneWidget, reason: 'makes each');
    expect(find.text('56% margin'), findsOneWidget);
    expect(find.text('₱2,400.00'), findsOneWidget, reason: '12 on hand × ₱200');
    expect(find.text('5 pieces'), findsOneWidget, reason: 'sold in the last 30 days: 2 + 1 + 2');

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Damaged'), findsOneWidget);
    expect(find.textContaining('Torn hem'), findsOneWidget);
    expect(find.text('Received from Divisoria bale'), findsOneWidget);
    expect(find.text('+14'), findsOneWidget);
  });

  testWidgets("an item's full history can be narrowed to a month or a day", (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openStock(tester);
    await tester.tap(find.text('Pleated skirt'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('All history'), 200, scrollable: find.byType(Scrollable).last);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All history'));
    await tester.pumpAndSettle();

    expect(find.text('5 sold · 14 received · 1 written off'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget, reason: 'everything, by month');

    await pickKind(tester, 'Day');
    expect(find.text('3 sold'), findsOneWidget, reason: "today's two sales");
    await stepEarlier(tester);
    expect(find.text('No changes yesterday.'), findsOneWidget);
    await stepEarlier(tester, times: 2);
    expect(find.text('1 written off'), findsOneWidget);
    expect(find.textContaining('Torn hem'), findsOneWidget);

    await pickKind(tester, 'Month');
    expect(find.text('September 2026'), findsOneWidget, reason: 'the day became its month');
    expect(find.text('Wed, Sep 23'), findsOneWidget, reason: 'a month, by day');
  });

  testWidgets('an item with no cost says what it makes is unknown', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openStock(tester);

    await tester.tap(find.text('Floral dress'));
    await tester.pumpAndSettle();

    expect(find.text('Not recorded'), findsOneWidget);
    expect(find.textContaining('No cost recorded yet'), findsOneWidget);
    expect(find.text('cost unknown'), findsOneWidget);
  });

  testWidgets('Stock and an item fit on a small phone', (tester) async {
    await _pumpApp(tester, initial: _connected, size: const Size(320, 568));
    await openStock(tester);
    expect(tester.takeException(), isNull);

    // Third in the grid, so below the fold on this screen.
    final page = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;
    await tester.drag(page, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pleated skirt'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  Future<void> openMoney(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tab-Money')));
    await tester.pumpAndSettle();
  }

  Finder moneyPage() => find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;

  testWidgets('Money shows how much of the investment is paid back', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openMoney(tester);

    // ₱470 earned since the books started, on ₱10,000 put in.
    expect(find.text('5%'), findsOneWidget);
    expect(find.text('₱470 earned back of ₱10,000 put in'), findsOneWidget);
    expect(find.text('Put in by Ana'), findsOneWidget);
    expect(find.text('₱9,470.00'), findsOneWidget, reason: 'still in the shop: 10,000 + 470 − 1,000 taken home');
    expect(find.text('₱2,400.00'), findsOneWidget, reason: 'stock on the rack: 12 skirts at ₱200');
    expect(find.textContaining('books started on September 1, 2026'), findsOneWidget);
  });

  testWidgets("Money breaks down the period's profit, like the shop computer", (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openMoney(tester);
    await tester.scrollUntilVisible(find.text('Net profit'), 200, scrollable: moneyPage());

    // This month, which is also when the books started.
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('from Sep 1'), findsNothing, reason: 'the month and the books start together');
    expect(find.text('₱2,850.00'), findsOneWidget, reason: 'sales');
    expect(find.text('₱1,670.00'), findsOneWidget, reason: 'gross profit');
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('₱470.00'), findsOneWidget, reason: 'net: 1,670 − 1,000 rent − 200 damaged');
    expect(find.textContaining('₱300.00 of these sales were stock from before the books started'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Earlier')),
      isSemantics(isEnabled: false, hasEnabledState: true),
      reason: 'nothing before the books started',
    );

    await tester.scrollUntilVisible(find.text('Since start'), -200, scrollable: moneyPage());
    await tester.tap(find.text('Since start'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Net profit'), 200, scrollable: moneyPage());
    expect(find.text('from Sep 1'), findsOneWidget);
    expect(find.text('September 2026'), findsNothing);
  });

  testWidgets('the money log lists entries and stock bought, by month', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openMoney(tester);
    await tester.scrollUntilVisible(find.text('Money log'), 200, scrollable: moneyPage());
    await tester.drag(moneyPage(), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Money log'));
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Stock from Divisoria bale'), findsOneWidget);
    expect(find.text('−₱2,800.00'), findsOneWidget);
    expect(find.text('Money put in'), findsOneWidget);
    expect(find.text('+₱10,000.00'), findsOneWidget);
    expect(find.text('Taken home'), findsOneWidget);
    expect(find.text('₱10,000 in · ₱4,800 out · 4 entries'), findsOneWidget);

    // A month is grouped by day.
    await pickKind(tester, 'Month');
    expect(find.text('Sun, Sep 20'), findsOneWidget);
    expect(find.text('Tue, Sep 1'), findsOneWidget);

    await pickKind(tester, 'Day');
    expect(find.text('Nothing recorded today.'), findsOneWidget);
    await stepEarlier(tester, times: 6);
    expect(find.text('Sun, Sep 20'), findsOneWidget);
    expect(find.text('Stock from Divisoria bale'), findsOneWidget);
    expect(find.text('Money put in'), findsNothing);
  });

  testWidgets('Money fits on a small phone', (tester) async {
    await _pumpApp(tester, initial: _connected, size: const Size(320, 568));
    await openMoney(tester);
    await tester.drag(moneyPage(), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab is labeled, and the selection moves with a tap', (tester) async {
    await _pumpApp(tester, initial: _connected);
    for (final tab in ['Today', 'Sales', 'Stock', 'Money', 'More']) {
      expect(find.descendant(of: find.byType(ShopTabBar), matching: find.text(tab)), findsOneWidget, reason: tab);
    }
    Matcher selected(bool on) => isSemantics(isSelected: on);
    expect(tester.getSemantics(find.byKey(const ValueKey('tab-Today'))), selected(true));
    expect(tester.getSemantics(find.byKey(const ValueKey('tab-Stock'))), selected(false));

    await tester.tap(find.byKey(const ValueKey('tab-Stock')));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.byKey(const ValueKey('tab-Stock'))), selected(true));
    expect(tester.getSemantics(find.byKey(const ValueKey('tab-Today'))), selected(false));
  });

  testWidgets('tapping the current tab again returns to its first screen', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await tester.tap(find.byKey(const ValueKey('tab-Stock')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic tee'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget, reason: 'on the item page');

    await tester.tap(find.byKey(const ValueKey('tab-Stock')));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
    expect(find.text('3 items · 15 pieces on hand'), findsOneWidget, reason: 'back on the Stock grid');
  });

  testWidgets('the tab bar fits a small phone on every tab', (tester) async {
    await _pumpApp(tester, initial: _connected, size: const Size(320, 568));
    for (final tab in ['Sales', 'Stock', 'Money', 'More', 'Today']) {
      await tester.tap(find.byKey(ValueKey('tab-$tab')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  test('the sync line reads naturally', () {
    final now = DateTime(2026, 9, 26, 15);
    expect(
      syncLabel(CloudSyncState(status: CloudStatus.upToDate, lastSyncedAt: DateTime(2026, 9, 26, 14, 46)), now: now),
      // intl puts a narrow no-break space before AM/PM.
      'Up to date · 2:46 PM',
    );
    expect(
      syncLabel(CloudSyncState(status: CloudStatus.upToDate, lastSyncedAt: DateTime(2026, 9, 24, 9)), now: now),
      'Up to date · Sep 24',
    );
    expect(syncLabel(const CloudSyncState(status: CloudStatus.offline)), 'Offline');
  });
}
