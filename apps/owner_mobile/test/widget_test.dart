// The app shell with a fake cloud connection: signing in, the five tabs,
// and signing out.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/app.dart';
import 'package:owner_mobile/presentation/screens/more/more_screen.dart';
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
/// Saturday's only sale, and a tee that's sold out.
final _now = DateTime(2026, 9, 26, 15);

Future<TodayViewModel> _seededToday() async {
  final sales = FakeSaleRepository();
  final items = FakeItemRepository();
  Sale sale(String id, DateTime at, double price, int qty) => Sale(
        id: id,
        dateTime: at,
        paymentMethod: PaymentMethod.cash,
        lineItems: [SaleLineItem(itemId: 'skirt', itemName: 'Pleated skirt', unitPrice: price, qty: qty, unitCost: 200)],
      );
  await sales.recordSale(sale('a', DateTime(2026, 9, 26, 10, 5), 450, 2));
  await sales.recordSale(sale('b', DateTime(2026, 9, 26, 14, 41), 450, 1));
  await sales.recordSale(sale('c', DateTime(2026, 9, 19, 11), 450, 2));
  await items.add(const Item(id: 'tee', name: 'Basic tee', category: 'T-Shirt', unitPrice: 150, qtyOnHand: 0));
  await items.add(const Item(id: 'skirt', name: 'Pleated skirt', category: 'Skirt', unitPrice: 450, qtyOnHand: 12));
  final today = TodayViewModel(sales, items, FakeReservationRepository(), FakeSettingsRepository(), clock: () => _now);
  await today.load();
  return today;
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
  await tester.pumpWidget(OwnerApp(cloudSync: sync, today: await _seededToday()));
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
    expect(find.text('Pleated skirt × 2'), findsWidgets);
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
