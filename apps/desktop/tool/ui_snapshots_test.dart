// Visual QA harness — renders every screen (light + dark) to PNG with the
// app's bundled Inter, so UI changes can be reviewed as images rather than
// inferred from code. Windows-only (reads the icon fonts from the Flutter
// SDK and the pub cache).
//
//   flutter test tool/ui_snapshots_test.dart
//
// Output: build/ui_snapshots/*.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:skirt_tee_studio/presentation/shell/app_shell.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/cart_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/inventory_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/money_view_model.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/reservation_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/sales_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/session_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/settings_view_model.dart';
import 'package:shop_core/domain/entities/staff.dart';
import 'package:skirt_tee_studio/presentation/screens/auth/sign_in_screen.dart';
import 'package:skirt_tee_studio/presentation/screens/inventory/widgets/category_field.dart';

import 'package:shop_core/testing/fake_cloud_sync_repository.dart';
import 'package:shop_core/testing/fake_money_repository.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';
import 'package:shop_core/testing/fake_reservation_repository.dart';
import 'package:shop_core/testing/fake_sale_repository.dart';
import 'package:shop_core/testing/fake_settings_repository.dart';
import '../test/fakes/fake_staff_repository.dart';
import 'package:shop_core/testing/fake_stock_repository.dart';

const _outDir = 'build/ui_snapshots';
final _boundaryKey = GlobalKey();

/// The screen's own page scroll, not a horizontal chip strip inside it.
final _verticalScroll = find
    .byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical)
    .first;

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(Future.value(ByteData.view(File(path).readAsBytesSync().buffer)));
  }
  await loader.load();
}

const _items = [
  Item(id: 'i1', name: 'Classic White Tee', category: 'T-Shirt', unitPrice: 199, qtyOnHand: 24, unitCost: 92),
  Item(id: 'i2', name: 'Vintage Band Tee', category: 'T-Shirt', unitPrice: 349, qtyOnHand: 3, unitCost: 161),
  Item(id: 'i3', name: 'Pleated Midi Skirt', category: 'Skirt', unitPrice: 499, qtyOnHand: 8, unitCost: 230),
  Item(id: 'i4', name: 'Denim Mini Skirt', category: 'Skirt', unitPrice: 399, qtyOnHand: 0),
  Item(id: 'i5', name: 'Linen Shorts', category: 'Shorts', unitPrice: 299, qtyOnHand: 12, unitCost: 138),
  Item(id: 'i6', name: 'Floral Wrap Blouse', category: 'Blouse', unitPrice: 459, qtyOnHand: 5),
  Item(id: 'i7', name: 'Ruffle Sleeve Blouse', category: 'Blouse', unitPrice: 129, qtyOnHand: 15, onSale: true, salePercent: 20),
  Item(id: 'i8', name: 'Kids Dino Tee', category: 'Kids', unitPrice: 149, qtyOnHand: 18, unitCost: 69),
  Item(id: 'i9', name: 'Kids Tutu Skirt', category: 'Kids', unitPrice: 99, qtyOnHand: 2, onSale: true),
  Item(id: 'i10', name: 'Oversized Graphic Tee', category: 'T-Shirt', unitPrice: 279, qtyOnHand: 9),
];

Future<Widget> _buildApp(ThemeMode mode) async {
  final stock = FakeStockRepository();
  final inventory = InventoryViewModel(stock.items, stock);
  for (final item in _items) {
    await inventory.addItem(item);
  }

  final saleRepo = FakeSaleRepository();
  final now = DateTime.now();
  var n = 0;
  for (var daysAgo = 27; daysAgo >= 0; daysAgo -= 2) {
    final item = _items[n % _items.length];
    final other = _items[(n + 3) % _items.length];
    await saleRepo.recordSale(Sale(
      id: 'sale-$n',
      dateTime: now.subtract(Duration(days: daysAgo, hours: n % 5)),
      paymentMethod: PaymentMethod.selectable[n % PaymentMethod.selectable.length],
      lineItems: [
        SaleLineItem(itemId: item.id, itemName: item.name, unitPrice: item.unitPrice, qty: 1 + n % 3),
        SaleLineItem(itemId: other.id, itemName: other.name, unitPrice: other.unitPrice, qty: 1),
      ],
    ));
    n++;
  }
  for (final (i, method) in [PaymentMethod.cash, PaymentMethod.gcash, PaymentMethod.cash].indexed) {
    final item = _items[i * 2];
    await saleRepo.recordSale(Sale(
      id: 'today-$i',
      dateTime: DateTime(now.year, now.month, now.day, 10 + i * 2),
      paymentMethod: method,
      lineItems: [SaleLineItem(itemId: item.id, itemName: item.name, unitPrice: item.unitPrice, qty: 1)],
    ));
  }
  // Money books started ~4 months ago: earlier months carry costs; the last
  // month's sales above carry none (stock from before the books), which is
  // exactly the transition the profit note explains.
  final booksStart = DateTime(now.year, now.month - 3, 6);
  for (var m = 3; m >= 1; m--) {
    for (var d = 0; d < 6; d++) {
      final item = _items[(m + d) % _items.length];
      await saleRepo.recordSale(Sale(
        id: 'm$m-$d',
        dateTime: DateTime(now.year, now.month - m, 8 + d * 3),
        paymentMethod: PaymentMethod.cash,
        lineItems: [
          SaleLineItem(
            itemId: item.id,
            itemName: item.name,
            unitPrice: item.unitPrice,
            qty: 3 + (m + d) % 4,
            unitCost: item.unitPrice * 0.48,
          ),
        ],
      ));
    }
  }
  final moneyRepo = FakeMoneyRepository(booksStartedAt: booksStart);
  final entries = [
    (MoneyEntryKind.capitalIn, 60000.0, 'Olivia Owner', null, 0, 'Startup cash'),
    (MoneyEntryKind.capitalIn, 40000.0, 'Marco Owner', null, 0, 'Racks & fitting room'),
    for (var m = 3; m >= 0; m--) (MoneyEntryKind.expense, 6500.0, null, ExpenseCategory.rent, m, ''),
    (MoneyEntryKind.expense, 1800.0, null, ExpenseCategory.marketing, 1, 'FB boost'),
    (MoneyEntryKind.expense, 650.0, null, ExpenseCategory.packaging, 0, ''),
    (MoneyEntryKind.ownerDraw, 5000.0, 'Olivia Owner', null, 1, ''),
  ];
  for (final (i, (kind, amount, person, category, monthsAgo, note)) in entries.indexed) {
    await moneyRepo.add(MoneyEntry(
      id: 'e$i',
      at: DateTime(now.year, now.month - monthsAgo, monthsAgo == 3 ? 6 : 2 + i),
      kind: kind,
      amount: amount,
      category: category,
      person: person,
      note: note,
    ));
  }
  stock.lots.add(StockLot(
    id: 'lot-1',
    at: DateTime(now.year, now.month - 2, 14),
    supplier: 'Divisoria bale #9',
    itemsCost: 8000,
    fees: 400,
    paidFrom: PaidFrom.owners,
  ));
  stock.movements.addAll([
    StockMovement(
      at: DateTime(now.year, now.month - 2, 14),
      itemId: 'i1',
      itemName: 'Classic White Tee',
      type: StockMovementType.received,
      qty: 52,
      unitCost: 161.54,
      lotId: 'lot-1',
    ),
    StockMovement(
      at: DateTime(now.year, now.month - 1, 20),
      itemId: 'i3',
      itemName: 'Pleated Midi Skirt',
      type: StockMovementType.writeOff,
      qty: 2,
      unitCost: 230,
      reason: WriteOffReason.damaged,
    ),
  ]);
  final money = MoneyViewModel(moneyRepo, stock);
  await money.load();

  final sales = SalesViewModel(saleRepo);
  await sales.load();

  final reservations = ReservationViewModel(FakeReservationRepository(), FakeSaleRepository());
  final seeds = [
    ('Maria Santos', '0917 555 0142', 'i3', 'Pleated Midi Skirt', 2, ReservationStatus.pending),
    ('Maria Santos', '0917 555 0142', 'i6', 'Floral Wrap Blouse', -12, ReservationStatus.pickedUp),
    ('Jasmine Reyes', 'fb.com/jas.reyes', 'i2', 'Vintage Band Tee', 1, ReservationStatus.pending),
    ('Carla Mendoza', '0928 444 0199', 'i5', 'Linen Shorts', 4, ReservationStatus.pending),
    ('Jasmine Reyes', 'fb.com/jas.reyes', 'i8', 'Kids Dino Tee', -5, ReservationStatus.pickedUp),
  ];
  for (var i = 0; i < seeds.length; i++) {
    final s = seeds[i];
    await reservations.addReservation(Reservation(
      id: 'r$i',
      customerName: s.$1,
      contact: s.$2,
      itemId: s.$3,
      itemName: s.$4,
      pickupDate: now.add(Duration(days: s.$5)),
      status: s.$6,
    ));
  }

  final cart = CartViewModel(FakeSaleRepository())
    ..addItem(_items[0])
    ..addItem(_items[0])
    ..addItem(_items[5]);

  final session = await signedInSession();
  await session.addStaff('Marco Owner', StaffRole.owner, '4321');
  await session.addStaff('Carl Reyes', StaffRole.cashier, '5678');
  await session.log('Sale ₱857.00 · 3 items');
  await session.log('Edited item "Vintage Band Tee" · stock 5 → 3');

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: inventory),
      ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider.value(value: reservations),
      ChangeNotifierProvider.value(value: sales),
      ChangeNotifierProvider(create: (_) => SettingsViewModel(FakeSettingsRepository())),
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: money),
      ChangeNotifierProvider(
        create: (_) => CloudSyncViewModel(FakeCloudSyncRepository(), onRemoteChanges: () async {})..load(),
      ),
    ],
    child: RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: Selector<SessionViewModel, bool>(
          selector: (_, s) => s.current != null,
          builder: (_, signedIn, _) => signedIn ? const AppShell() : const SignInScreen(),
        ),
      ),
    ),
  );
}

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await _snapNoSettle(tester, name);
}

/// Captures the current frame without settling — for mid-animation frames.
Future<void> _snapNoSettle(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    Directory(_outDir).createSync(recursive: true);
    // Inter's four weights, as the app bundles them; also standing in for
    // anything that still asks for the system font.
    final inter = [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Inter-$w.ttf'];
    for (final family in ['Inter', 'CupertinoSystemText', 'CupertinoSystemDisplay', 'FlutterTest']) {
      await _loadFont(family, inter);
    }
    final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    await _loadFont('MaterialIcons', ['$flutterRoot\\bin\\cache\\artifacts\\material_fonts\\materialicons-regular.otf']);
    final pubCache = p.join(Platform.environment['LOCALAPPDATA']!, 'Pub', 'Cache', 'hosted', 'pub.dev');
    await _loadFont('packages/cupertino_icons/CupertinoIcons', [p.join(pubCache, 'cupertino_icons-1.0.9', 'assets', 'CupertinoIcons.ttf')]);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode == ThemeMode.light ? 'light' : 'dark';

    testWidgets('snapshots ($suffix)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await _buildApp(mode));
      await _snap(tester, '1_pos_$suffix');

      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('₱1,000.00'));
      await _snap(tester, '1a_cash_tender_$suffix');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Sale'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150))); // lottie asset load
      await tester.pump(const Duration(milliseconds: 250));
      await _snapNoSettle(tester, '1b_sale_anim_mid_$suffix');
      await tester.pump(const Duration(milliseconds: 900));
      await _snapNoSettle(tester, '1c_sale_anim_end_$suffix');
      await tester.pump(const Duration(seconds: 3)); // let the success state time out

      for (final (label, file) in [
        ('Inventory', '2_inventory'),
        ('Reservations', '3_reservations'),
        ('Sales', '4_sales'),
        ('Reports', '5_reports'),
        ('Customers', '6_customers'),
        ('Staff', '8_staff'),
        ('Settings', '11_settings'),
        ('Money', '7_money'),
      ]) {
        await tester.tap(find.text(label).first);
        await _snap(tester, '${file}_$suffix');
      }

      // The rest of the Money screen, and its entry dialog.
      await tester.drag(_verticalScroll, const Offset(0, -700));
      await _snap(tester, '7a_money_log_$suffix');
      await tester.tap(find.text('Record Expense'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₱)'), '1,250');
      await tester.tap(find.text('Our own money'));
      await _snap(tester, '7b_expense_dialog_$suffix');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1100, 640);
      await tester.drag(_verticalScroll, const Offset(0, 1400));
      await _snap(tester, '7c_money_min_window_$suffix');
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();

      // Stock dialogs, opened over Inventory.
      await tester.tap(find.text('Inventory').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Receive Stock'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Supplier or source'), 'Divisoria bale #14');
      await tester.enterText(find.widgetWithText(TextFormField, 'Price paid for the lot (₱)'), '8,000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Shipping & other fees (₱)'), '400');
      for (final name in ['Classic White Tee', 'Pleated Midi Skirt', 'Kids Dino Tee']) {
        await tester.enterText(find.widgetWithText(TextField, 'Add an item from inventory'), name.substring(0, 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }
      final qty = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '0');
      for (final (i, n) in ['30', '12', '10'].indexed) {
        await tester.enterText(qty.at(i), n);
      }
      // A kind that isn't in inventory yet, from the quick line.
      await tester.tap(find.byType(CategoryField));
      await tester.pumpAndSettle();
      await _snap(tester, '2a0_quick_category_menu_$suffix');
      await tester.tap(find.text('Long Sleeves').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Sells for ₱'), '249');
      await tester.enterText(find.widgetWithText(TextField, 'Pieces'), '8');
      await tester.tap(find.text('Add'));
      await tester.tap(find.text('Our own money'));
      await _snap(tester, '2a_receive_stock_$suffix');
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -600));
      await _snap(tester, '2a1_receive_stock_bottom_$suffix');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Adjust stock').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Pieces'), '2');
      await _snap(tester, '2b_adjust_stock_$suffix');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add or remove categories'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'New category, e.g. Dress'), 'Dress');
      await tester.tap(find.text('Add'));
      await _snap(tester, '2e_categories_$suffix');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ruffle Sleeve Blouse'));
      await _snap(tester, '2f_item_on_sale_$suffix');
      await tester.tap(find.text('Sale price'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Sale price (₱)'), '99');
      await _snap(tester, '2g_item_sale_price_$suffix');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The smallest window the runner allows (win32_window.cpp, less the
      // frame) — the Inventory header carries the most actions of any screen.
      tester.view.physicalSize = const Size(1100, 640);
      await _snap(tester, '2c_inventory_min_window_$suffix');
      await tester.tap(find.text('Receive Stock'));
      await _snap(tester, '2d_receive_stock_min_window_$suffix');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Lock'));
      await _snap(tester, '9_sign_in_$suffix');
      await tester.tap(find.text('Carl Reyes'));
      await _snap(tester, '9b_sign_in_pin_$suffix');
      await tester.enterText(find.byType(TextField), '5678');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await _snap(tester, '10_cashier_pos_$suffix');


      debugDefaultTargetPlatformOverride = null;
    });
  }
}
