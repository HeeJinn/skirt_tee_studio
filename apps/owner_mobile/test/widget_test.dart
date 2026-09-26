// The app with a fake cloud connection and a seeded shop: signing in, the
// tabs, and signing out.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/app.dart';
import 'package:owner_mobile/presentation/screens/more/more_screen.dart';
import 'package:owner_mobile/presentation/viewmodels/sales_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/today_view_model.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/testing/fake_cloud_sync_repository.dart';
import 'package:shop_core/testing/fake_item_repository.dart';
import 'package:shop_core/testing/fake_reservation_repository.dart';
import 'package:shop_core/testing/fake_sale_repository.dart';
import 'package:shop_core/testing/fake_settings_repository.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

/// A Saturday at the shop: two sales so far, one of them bigger than last
/// Saturday's only sale, a mixed GCash sale on Tuesday (one piece with no
/// recorded cost), and a tee that's sold out.
final _now = DateTime(2026, 9, 26, 15);

late FakeSaleRepository _saleRepo;
late SalesViewModel _salesVm;

Future<(TodayViewModel, SalesViewModel)> _seededShop() async {
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
  await items.add(const Item(id: 'skirt', name: 'Pleated skirt', category: 'Skirt', unitPrice: 450, qtyOnHand: 12));
  final today = TodayViewModel(sales, items, FakeReservationRepository(), FakeSettingsRepository(), clock: () => _now);
  final salesVm = _salesVm = SalesViewModel(sales, clock: () => _now);
  await Future.wait([today.load(), salesVm.load()]);
  return (today, salesVm);
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
  final (today, sales) = await _seededShop();
  await tester.pumpWidget(OwnerApp(cloudSync: sync, today: today, sales: sales));
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
