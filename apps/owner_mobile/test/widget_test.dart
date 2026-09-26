// The app with a fake cloud connection and a seeded shop: signing in, the
// tabs, and signing out.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/app.dart';
import 'package:owner_mobile/presentation/screens/more/more_screen.dart';
import 'package:owner_mobile/presentation/viewmodels/money_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/sales_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/stock_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/today_view_model.dart';
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
  testWidgets('signing in with the wrong password shows why and stays on sign-in', (tester) async {
    await _pumpApp(tester);

    await tester.enterText(find.byType(CupertinoTextFormFieldRow).at(0), 'owner@example.com');
    await tester.enterText(find.byType(CupertinoTextFormFieldRow).at(1), 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text("That email and password don't match."), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('an empty email is caught before signing in', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text("Enter the account's email."), findsOneWidget);
  });

  testWidgets('a good sign-in opens the five tabs', (tester) async {
    await _pumpApp(tester);

    await tester.enterText(find.byType(CupertinoTextFormFieldRow).at(0), 'owner@example.com');
    await tester.enterText(find.byType(CupertinoTextFormFieldRow).at(1), FakeCloudSyncRepository.goodPassword);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final tab in ['Today', 'Sales', 'Stock', 'Money', 'More']) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
  });

  testWidgets('each tab opens without layout errors', (tester) async {
    await _pumpApp(tester, initial: _connected);

    for (final tab in ['Sales', 'Stock', 'Money', 'More', 'Today']) {
      await tester.tap(find.descendant(of: find.byType(CupertinoTabBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('More shows the account, and signing out asks first', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await tester.tap(find.descendant(of: find.byType(CupertinoTabBar), matching: find.text('More')));
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
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets("Today shows the day's numbers against last week, and what needs attention", (tester) async {
    await _pumpApp(tester, initial: _connected);

    expect(find.text('₱1,350'), findsOneWidget, reason: 'sales today');
    expect(find.text('+50% vs last Sat'), findsNWidgets(3), reason: 'sales, profit, and pieces all rose by half');
    expect(find.text('+100% vs last Sat'), findsOneWidget, reason: 'two sales against one');
    expect(find.text('₱750'), findsOneWidget, reason: 'gross profit: 3 × (₱450 − ₱200)');
    expect(find.text('1 item sold out'), findsOneWidget);
    expect(find.text('Basic tee'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('LATEST SALES'),
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
    await tester.tap(find.descendant(of: find.byType(CupertinoTabBar), matching: find.text('Sales')));
    await tester.pumpAndSettle();
  }

  Future<void> pickRange(WidgetTester tester, String label) async {
    // The period labels appear only in the switch.
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets("Sales opens on today's sales, grouped under the day's total", (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);

    expect(find.text('₱1,350 · 2 sales · 3 pieces'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Pleated skirt ×2'), findsOneWidget);
    expect(find.text('Pleated skirt'), findsOneWidget);
    expect(find.text('Basic tee ×2, Vintage blouse'), findsNothing, reason: "Tuesday's sale isn't today");
  });

  testWidgets('a longer period adds earlier days, newest first', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);

    await pickRange(tester, '7 days');
    expect(find.text('₱1,950 · 3 sales · 6 pieces'), findsOneWidget);
    expect(find.text('TUE, SEP 22'), findsOneWidget);
    expect(find.text('Basic tee ×2, Vintage blouse'), findsOneWidget);
    expect(find.text('SAT, SEP 19'), findsNothing);

    await pickRange(tester, '30 days');
    await tester.scrollUntilVisible(
      find.text('SAT, SEP 19'),
      200,
      scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('SAT, SEP 19'), findsOneWidget);
  });

  testWidgets('a sale shows its payment, change, and what the shop made', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);

    await tester.tap(find.text('Pleated skirt ×2'));
    await tester.pumpAndSettle();

    expect(find.text('₱900.00'), findsWidgets);
    expect(find.text('Cash received'), findsOneWidget);
    expect(find.text('₱1,000.00'), findsOneWidget);
    expect(find.text('₱100.00'), findsOneWidget, reason: 'change');
    expect(find.text('₱500.00'), findsOneWidget, reason: 'gross profit: 2 × (₱450 − ₱200)');
    expect(find.textContaining('reads high'), findsNothing);
  });

  testWidgets('a sale with an uncosted piece says its profit reads high', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openSales(tester);
    await pickRange(tester, '7 days');

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
    expect(find.descendant(of: navBar, matching: find.text('Today')), findsOneWidget, reason: 'the back button');
  });

  testWidgets('Sales and a sale fit on a small phone', (tester) async {
    await _pumpApp(tester, initial: _connected, size: const Size(320, 568));
    await openSales(tester);
    await pickRange(tester, '30 days');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Pleated skirt ×2').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  Future<void> openStock(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(CupertinoTabBar), matching: find.text('Stock')));
    await tester.pumpAndSettle();
  }

  testWidgets('Stock shows every item with how many are left', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openStock(tester);

    expect(find.text('3 items · 15 pieces on hand'), findsOneWidget);
    expect(find.text('Low (1)'), findsOneWidget);
    expect(find.text('Sold out (1)'), findsOneWidget);
    expect(find.text('Basic tee'), findsOneWidget);
    expect(find.text('₱150.00 · Sold out'), findsOneWidget);
    expect(find.text('₱600.00 · 3 left'), findsOneWidget);
    expect(find.text('₱450.00 · 12 left'), findsOneWidget);
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
    expect(find.text('₱250.00 (56%)'), findsOneWidget);
    expect(find.text('₱2,400.00'), findsOneWidget, reason: '12 on hand × ₱200');
    expect(find.text('5 pieces'), findsOneWidget, reason: 'sold in the last 30 days: 2 + 1 + 2');

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Damaged'), findsOneWidget);
    expect(find.textContaining('Torn hem'), findsOneWidget);
    expect(find.text('Received from Divisoria bale'), findsOneWidget);
    expect(find.text('+14'), findsOneWidget);
  });

  testWidgets('an item with no cost says what it makes is unknown', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openStock(tester);

    await tester.tap(find.text('Floral dress'));
    await tester.pumpAndSettle();

    expect(find.text('Not recorded'), findsOneWidget);
    expect(find.textContaining('No cost recorded yet'), findsOneWidget);
    expect(find.text('Makes per piece'), findsNothing);
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
    await tester.tap(find.descendant(of: find.byType(CupertinoTabBar), matching: find.text('Money')));
    await tester.pumpAndSettle();
  }

  Finder moneyPage() => find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;

  testWidgets('Money shows how much of the investment is paid back', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openMoney(tester);

    // ₱470 earned since the books started, on ₱10,000 put in.
    expect(find.text('5%'), findsOneWidget);
    expect(find.textContaining('₱470 earned of ₱10,000 put in'), findsOneWidget);
    expect(find.text('Put in by Ana'), findsOneWidget);
    expect(find.text('₱9,470.00'), findsOneWidget, reason: 'still in the shop: 10,000 + 470 − 1,000 taken home');
    expect(find.text('₱2,400.00'), findsOneWidget, reason: 'stock on the rack: 12 skirts at ₱200');
    expect(find.textContaining('books started on Sep 1, 2026'), findsOneWidget);
  });

  testWidgets("Money breaks down the period's profit, like the shop computer", (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openMoney(tester);
    await tester.scrollUntilVisible(find.text('Net profit'), 200, scrollable: moneyPage());

    // Last 30 days, from Sep 1 (the books started after the period did).
    expect(find.text('PROFIT FROM SEP 1'), findsOneWidget);
    expect(find.text('₱2,850.00'), findsOneWidget, reason: 'sales');
    expect(find.text('₱1,670.00'), findsOneWidget, reason: 'gross profit');
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('₱470.00'), findsOneWidget, reason: 'net: 1,670 − 1,000 rent − 200 damaged');
    expect(find.textContaining('₱300.00 of these sales were stock from before the books started'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('7 days'), -200, scrollable: moneyPage());
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Net profit'), 200, scrollable: moneyPage());
    expect(find.text('PROFIT FROM SEP 20'), findsOneWidget);
    expect(find.text('₱970.00'), findsOneWidget, reason: 'no rent this week');
  });

  testWidgets('the money log lists entries and stock bought, by month', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await openMoney(tester);
    await tester.scrollUntilVisible(find.text('Money log'), 200, scrollable: moneyPage());
    await tester.drag(moneyPage(), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Money log'));
    await tester.pumpAndSettle();

    expect(find.text('SEPTEMBER 2026'), findsOneWidget);
    expect(find.text('Stock from Divisoria bale'), findsOneWidget);
    expect(find.text('−₱2,800.00'), findsOneWidget);
    expect(find.text('Money put in'), findsOneWidget);
    expect(find.text('+₱10,000.00'), findsOneWidget);
    expect(find.text('Taken home'), findsOneWidget);
  });

  testWidgets('Money fits on a small phone', (tester) async {
    await _pumpApp(tester, initial: _connected, size: const Size(320, 568));
    await openMoney(tester);
    await tester.drag(moneyPage(), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
