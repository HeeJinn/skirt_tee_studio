// App-shell smoke test: builds with fake repositories (no real database)
// and checks the three screens are wired into the nav. Business logic
// (cart math, checkout, CRUD) is covered by the ViewModel unit tests in
// test/presentation/viewmodels/ instead of driving it through widget taps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/appearance.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/staff.dart';
import 'package:skirt_tee_studio/presentation/shell/app_shell.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/cart_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/cloud_sync_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/inventory_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/money_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/reservation_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/sales_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/session_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/settings_view_model.dart';

import 'fakes/fake_cloud_sync_repository.dart';
import 'fakes/fake_item_repository.dart';
import 'fakes/fake_money_repository.dart';
import 'fakes/fake_reservation_repository.dart';
import 'fakes/fake_sale_repository.dart';
import 'fakes/fake_settings_repository.dart';
import 'fakes/fake_staff_repository.dart';
import 'fakes/fake_stock_repository.dart';

Widget _buildApp(SessionViewModel session, FakeCloudSyncRepository cloud) {
  final inventoryViewModel = InventoryViewModel(FakeItemRepository(), FakeStockRepository())
    ..addItem(const Item(
      id: 'item-1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 5,
    ));

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: inventoryViewModel),
      ChangeNotifierProvider(create: (_) => CartViewModel(FakeSaleRepository())),
      ChangeNotifierProvider(
        create: (_) => ReservationViewModel(FakeReservationRepository(), FakeSaleRepository()),
      ),
      ChangeNotifierProvider(create: (_) => SalesViewModel(FakeSaleRepository())),
      ChangeNotifierProvider(create: (_) => SettingsViewModel(FakeSettingsRepository())),
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider(create: (_) => MoneyViewModel(FakeMoneyRepository(), FakeStockRepository())),
      ChangeNotifierProvider(create: (_) => CloudSyncViewModel(cloud, onRemoteChanges: () async {})..load()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
  );
}

/// Pumps the shell at a real desktop size — the Windows runner enforces a
/// minimum window of ~1100x640, so the 800x600 test default isn't a size
/// the app can actually be shown at.
Future<void> _pumpApp(
  WidgetTester tester, {
  StaffRole role = StaffRole.owner,
  FakeCloudSyncRepository? cloud,
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildApp(await signedInSession(role: role), cloud ?? FakeCloudSyncRepository()));
}

void main() {
  testWidgets('a cashier sees no owner-only screens and cannot edit stock', (tester) async {
    await _pumpApp(tester, role: StaffRole.cashier);
    await tester.pumpAndSettle();

    for (final ownerOnly in ['Staff', 'Sales', 'Reports', 'Money', 'Customers', 'Back up data']) {
      expect(find.text(ownerOnly), findsNothing, reason: ownerOnly);
    }

    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('Basic Tee'), findsOneWidget);
    expect(find.text('ADD ITEM'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
  });

  testWidgets(
      'App shell renders with POS, Inventory, Reservations, Sales, Reports, Customers nav',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('POS'), findsWidgets);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
  });

  testWidgets('Settings shows every theme, applies a pick, and closes on nav', (tester) async {
    await _pumpApp(tester, role: StaffRole.cashier);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('CLOUD BACKUP'), findsNothing, reason: 'cloud backup is for owners');
    for (final preset in ThemePresets.all) {
      expect(find.text(preset.name), findsOneWidget, reason: preset.name);
    }

    final settings = tester.element(find.byType(AppShell)).read<SettingsViewModel>();
    await tester.tap(find.text('Blush Atelier'));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(settings.themePreset, ThemePresets.blushAtelier);
    expect(settings.appearanceMode, AppearanceMode.dark);

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();
    expect(find.text('Blush Atelier'), findsNothing);
    expect(find.text('Basic Tee'), findsOneWidget);
  });

  testWidgets('an owner connects this computer to the cloud from Settings', (tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('Backed up'), findsNothing, reason: 'no sidebar status until connected');

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('CLOUD BACKUP'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);

    await tester.tap(find.text('CONNECT TO CLOUD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'owner@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong');
    await tester.tap(find.text('CONNECT'));
    await tester.pumpAndSettle();
    expect(find.text("That email and password don't match."), findsOneWidget, reason: 'stays open to retry');

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), FakeCloudSyncRepository.goodPassword);
    await tester.tap(find.text('CONNECT'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Backed up'), findsNWidgets(2), reason: 'Settings panel and sidebar');
    expect(find.text('Signed in as owner@example.com'), findsOneWidget);
  });

  testWidgets('a connected owner sees when changes are waiting offline', (tester) async {
    final cloud = FakeCloudSyncRepository(
      initial: const CloudSyncState(status: CloudStatus.offline, email: 'owner@example.com', pendingChanges: 3),
    );
    await _pumpApp(tester, cloud: cloud);
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
    expect(find.byTooltip('3 changes will upload when the internet is back'), findsOneWidget);
  });

  testWidgets('the sidebar fits the smallest window the runner allows, cloud status and all', (tester) async {
    // windows/runner/win32_window.cpp: minimum track size 1116 x 680.
    final cloud = FakeCloudSyncRepository(
      initial: const CloudSyncState(status: CloudStatus.upToDate, email: 'owner@example.com'),
    );
    await _pumpApp(tester, cloud: cloud, size: const Size(1116, 680));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'no overflow stripes');
    expect(find.text('Backed up'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Back up data'), findsOneWidget);
  });

  test('every preset builds a light and dark theme from its own palette', () {
    for (final preset in ThemePresets.all) {
      for (final palette in [preset.light, preset.dark]) {
        final theme = AppTheme.fromPalette(palette);
        expect(theme.brightness, palette.brightness);
        expect(theme.colorScheme.primary, palette.brand);
        expect(theme.extension<AppTokens>(), palette.tokens);
      }
    }
  });

  testWidgets('Customers screen shows reservation customers grouped by contact, no exceptions',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No customers found'), findsOneWidget);
  });

  testWidgets('POS screen lists inventory items', (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Basic Tee'), findsOneWidget);
  });

  testWidgets('switching to Inventory shows the Add Item button',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

    expect(find.text('ADD ITEM'), findsOneWidget);
  });

  testWidgets('Money screen opens on an empty book with no exceptions', (tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Nothing put in yet'), findsOneWidget);
    expect(find.text('Nothing recorded yet'), findsOneWidget);
  });

  testWidgets('opening Add Item shows the photo picker with no exceptions',      (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD ITEM'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ADD PHOTO'), findsOneWidget);
    expect(find.text('REMOVE'), findsNothing);
  });
}
