// Visual QA harness — renders the owner app's screens (light + dark) at
// iPhone 15 size to PNG, so UI changes can be reviewed as images rather
// than inferred from code. Windows-only: the app sets its text in Inter off
// Apple devices (see uiFontFamily), loaded here from the app's assets; the
// Georgia titles come from C:\Windows\Fonts.
//
//   flutter test tool/ui_snapshots_test.dart
//
// Output: build/ui_snapshots/*.png

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/app.dart';
import 'package:owner_mobile/presentation/viewmodels/money_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/sales_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/stock_view_model.dart';
import 'package:owner_mobile/presentation/viewmodels/today_view_model.dart';
import 'package:owner_mobile/presentation/widgets/ui/glass.dart';
import 'package:path/path.dart' as p;
import 'package:shop_core/data/datasources/local/item_image_storage.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/reservation.dart';
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

const _outDir = 'build/ui_snapshots';
final _boundaryKey = GlobalKey();

/// A Saturday late afternoon.
final _now = DateTime(2026, 9, 26, 17, 30);

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(Future.value(ByteData.view(File(path).readAsBytesSync().buffer)));
  }
  await loader.load();
}

/// (id, name, category, price, on hand, cost, photo color or null)
const _items = [
  ('i1', 'Classic White Tee', 'T-Shirt', 199.0, 24, 92.0, 0xFFE9E4DA),
  ('i2', 'Vintage Band Tee', 'T-Shirt', 349.0, 3, 161.0, 0xFF2F3437),
  ('i3', 'Pleated Midi Skirt', 'Skirt', 499.0, 8, 230.0, 0xFF8C9A7B),
  ('i4', 'Denim Mini Skirt', 'Skirt', 399.0, 0, null, 0xFF4A6285),
  ('i5', 'Linen Shorts', 'Shorts', 299.0, 12, 138.0, 0xFFCDB89A),
  ('i6', 'Floral Wrap Blouse', 'Blouse', 459.0, 5, null, 0xFFC98B8B),
  ('i7', 'Ruffle Sleeve Blouse', 'Blouse', 129.0, 15, 60.0, null),
  ('i8', 'Kids Dino Tee', 'Kids', 149.0, 18, 69.0, 0xFF7FA37A),
  ('i9', 'Kids Tutu Skirt', 'Kids', 99.0, 2, 45.0, null),
  ('i10', 'Oversized Graphic Tee', 'T-Shirt', 279.0, 9, 120.0, 0xFF6B5B7A),
];

/// Decodes a photo into Flutter's image cache. Done before the app is built,
/// on the real clock: an Image.file first resolved under the test's fake
/// clock never finishes loading.
Future<void> _warm(String path) {
  final done = Completer<void>();
  final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      stream.removeListener(listener);
      done.complete();
    },
    onError: (_, _) {
      stream.removeListener(listener);
      done.complete();
    },
  );
  stream.addListener(listener);
  return done.future;
}

/// A flat two-tone "fabric" swatch standing in for a product photo.
Future<void> _writeSwatch(String path, int color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final base = Color(color);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 300), Paint()..color = base);
  final shade = Color.lerp(base, const Color(0xFF000000), 0.12)!;
  for (var y = 0.0; y < 300; y += 18) {
    canvas.drawRect(Rect.fromLTWH(0, y, 300, 6), Paint()..color = shade);
  }
  final image = await recorder.endRecording().toImage(300, 300);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Sale _sale(String id, DateTime at, PaymentMethod method, List<(String, int)> lines, {double? tendered}) {
  final byId = {for (final i in _items) i.$1: i};
  return Sale(
    id: id,
    dateTime: at,
    paymentMethod: method,
    amountTendered: tendered,
    lineItems: [
      for (final (itemId, qty) in lines)
        SaleLineItem(
          itemId: itemId,
          itemName: byId[itemId]!.$2,
          unitPrice: byId[itemId]!.$4,
          qty: qty,
          unitCost: byId[itemId]!.$6,
        ),
    ],
  );
}

Future<Widget> _buildApp(String imagesDir) async {
  // A test harness, living in tool/ rather than test/.
  // ignore: invalid_use_of_visible_for_testing_member
  ItemImageStorage.instance.useDirectory(imagesDir);
  final items = FakeItemRepository();
  for (final (id, name, category, price, qty, cost, color) in _items) {
    String? path;
    if (color != null) {
      path = p.join(imagesDir, '$id.png');
      await _writeSwatch(path, color);
      await _warm(path);
    }
    await items.add(Item(
      id: id,
      name: name,
      category: category,
      unitPrice: price,
      qtyOnHand: qty,
      unitCost: cost,
      imagePath: path,
      isBargain: id == 'i7' || id == 'i9',
    ));
  }

  final today = DateTime(_now.year, _now.month, _now.day);
  DateTime at(int daysAgo, int hour, int minute) => today.subtract(Duration(days: daysAgo)).add(Duration(hours: hour, minutes: minute));
  final sales = FakeSaleRepository();
  for (final sale in [
    _sale('s1', at(0, 10, 12), PaymentMethod.cash, [('i1', 2)], tendered: 500),
    _sale('s2', at(0, 11, 40), PaymentMethod.gcash, [('i3', 1), ('i5', 1)]),
    _sale('s3', at(0, 13, 5), PaymentMethod.cash, [('i6', 1)], tendered: 500),
    _sale('s4', at(0, 14, 41), PaymentMethod.maya, [('i10', 2), ('i8', 1)]),
    _sale('s5', at(0, 16, 20), PaymentMethod.card, [('i2', 1)]),
    _sale('s6', at(1, 15, 2), PaymentMethod.cash, [('i1', 3)], tendered: 600),
    _sale('s7', at(1, 18, 10), PaymentMethod.gcash, [('i3', 2)]),
    _sale('s8', at(2, 12, 0), PaymentMethod.cash, [('i5', 1), ('i9', 2)], tendered: 500),
    _sale('s9', at(3, 16, 45), PaymentMethod.gcash, [('i10', 1)]),
    _sale('s10', at(4, 11, 30), PaymentMethod.cash, [('i7', 3)], tendered: 400),
    _sale('s11', at(5, 17, 15), PaymentMethod.maya, [('i1', 1), ('i2', 1)]),
    _sale('s12', at(7, 13, 0), PaymentMethod.cash, [('i3', 1), ('i1', 2)], tendered: 1000),
    _sale('s13', at(9, 15, 20), PaymentMethod.gcash, [('i4', 2)]),
    _sale('s14', at(14, 10, 0), PaymentMethod.cash, [('i5', 2)], tendered: 600),
    _sale('s15', at(35, 14, 0), PaymentMethod.gcash, [('i3', 3), ('i1', 4)]),
  ]) {
    await sales.recordSale(sale);
  }

  final reservations = FakeReservationRepository();
  await reservations.add(Reservation(
    id: 'r1', customerName: 'Bea', contact: '0917', itemId: 'i6', itemName: 'Floral Wrap Blouse', pickupDate: today));
  await reservations.add(Reservation(
    id: 'r2', customerName: 'Joy', contact: 'fb/joy', itemId: 'i2', itemName: 'Vintage Band Tee',
    pickupDate: today.subtract(const Duration(days: 2))));

  final stock = FakeStockRepository(items);
  stock.lots.add(StockLot(id: 'lot-1', at: at(20, 9, 0), supplier: 'Divisoria bale', itemsCost: 6500, fees: 300));
  stock.movements.addAll([
    StockMovement(at: at(20, 9, 0), itemId: 'i3', itemName: 'Pleated Midi Skirt', type: StockMovementType.received, qty: 12, unitCost: 230, lotId: 'lot-1'),
    StockMovement(at: at(6, 17, 0), itemId: 'i3', itemName: 'Pleated Midi Skirt', type: StockMovementType.writeOff, qty: 1, unitCost: 230, reason: WriteOffReason.damaged, note: 'Torn hem'),
  ]);

  final money = FakeMoneyRepository(booksStartedAt: DateTime(2026, 8, 1));
  for (final e in [
    MoneyEntry(id: 'm1', at: DateTime(2026, 8, 1, 9), kind: MoneyEntryKind.capitalIn, amount: 30000, paidFrom: PaidFrom.owners, person: 'Ana'),
    MoneyEntry(id: 'm2', at: DateTime(2026, 8, 1, 9), kind: MoneyEntryKind.capitalIn, amount: 20000, paidFrom: PaidFrom.owners, person: 'Ben'),
    MoneyEntry(id: 'm3', at: DateTime(2026, 9, 5, 9), kind: MoneyEntryKind.expense, amount: 4000, category: ExpenseCategory.rent),
    MoneyEntry(id: 'm4', at: DateTime(2026, 9, 12, 9), kind: MoneyEntryKind.expense, amount: 650, category: ExpenseCategory.packaging),
    MoneyEntry(id: 'm5', at: DateTime(2026, 9, 20, 9), kind: MoneyEntryKind.ownerDraw, amount: 2000, person: 'Ana'),
  ]) {
    await money.add(e);
  }

  return _app(items, sales, reservations, stock, money);
}

/// A shop that has recorded nothing yet, for the empty states.
Future<Widget> _buildEmptyApp() {
  final items = FakeItemRepository();
  return _app(items, FakeSaleRepository(), FakeReservationRepository(), FakeStockRepository(items), FakeMoneyRepository());
}

Future<Widget> _app(
  FakeItemRepository items,
  FakeSaleRepository sales,
  FakeReservationRepository reservations,
  FakeStockRepository stock,
  FakeMoneyRepository money,
) async {
  final settings = FakeSettingsRepository();
  final todayVm = TodayViewModel(sales, items, reservations, settings, clock: () => _now);
  final salesVm = SalesViewModel(sales, clock: () => _now);
  final stockVm = StockViewModel(items, stock, sales, settings, clock: () => _now);
  final moneyVm = MoneyViewModel(money, sales, stock, items, clock: () => _now);
  final sync = CloudSyncViewModel(
    FakeCloudSyncRepository(
      initial: CloudSyncState(status: CloudStatus.upToDate, email: 'ana@skirtandtee.ph', lastSyncedAt: DateTime.now()),
    ),
    onRemoteChanges: () async {},
  );
  await Future.wait([sync.load(), todayVm.load(), salesVm.load(), stockVm.load(), moneyVm.load()]);

  return RepaintBoundary(
    key: _boundaryKey,
    child: OwnerApp(cloudSync: sync, today: todayVm, sales: salesVm, stock: stockVm, money: moneyVm),
  );
}

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Finder _page() => find.descendant(of: find.byType(Scrollable), matching: find.byType(Viewport)).first;

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('tab-$label')));
  await tester.pumpAndSettle();
}

Future<void> _scroll(WidgetTester tester, double by) async {
  await tester.drag(_page(), Offset(0, -by));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(ShopBackButton).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Directory(_outDir).createSync(recursive: true);
    const fonts = r'C:\Windows\Fonts';
    // Inter's four weights, as the app bundles them; also standing in for
    // anything that still asks for the system font.
    final inter = [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Inter-$w.ttf'];
    for (final family in ['Inter', 'CupertinoSystemText', 'CupertinoSystemDisplay', 'FlutterTest']) {
      await _loadFont(family, inter);
    }
    // The serif of the large titles (on iPhones too).
    await _loadFont('Georgia', ['$fonts\\georgia.ttf', '$fonts\\georgiab.ttf']);
    final pubCache = p.join(Platform.environment['LOCALAPPDATA']!, 'Pub', 'Cache', 'hosted', 'pub.dev');
    await _loadFont('packages/cupertino_icons/CupertinoIcons', [p.join(pubCache, 'cupertino_icons-1.0.9', 'assets', 'CupertinoIcons.ttf')]);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final suffix = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('snapshots ($suffix)', timeout: const Timeout(Duration(minutes: 3)), (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });

      final imagesDir = (await tester.runAsync(() => Directory.systemTemp.createTemp('owner_snap')))!.path;
      final app = (await tester.runAsync(() => _buildApp(imagesDir)))!;
      await tester.pumpWidget(app);
      // Let Image.file decode the swatches.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await _snap(tester, 'today_$suffix');
      await _scroll(tester, 520);
      await _snap(tester, 'today_scrolled_$suffix');

      await _tab(tester, 'Sales');
      await _snap(tester, 'sales_$suffix');
      await tester.tap(find.bySemanticsLabel('Earlier'));
      await _snap(tester, 'sales_yesterday_$suffix');
      await tester.tap(find.bySemanticsLabel('Pick a day'));
      await _snap(tester, 'sales_day_picker_$suffix');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Month'));
      await _snap(tester, 'sales_month_$suffix');
      await tester.tap(find.bySemanticsLabel('Pick a month'));
      await _snap(tester, 'sales_month_picker_$suffix');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Oversized Graphic Tee').first);
      await _snap(tester, 'sale_detail_$suffix');
      await _back(tester);

      await _tab(tester, 'Stock');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await _snap(tester, 'stock_$suffix');
      await tester.scrollUntilVisible(
        find.text('Pleated Midi Skirt'),
        200,
        scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
      );
      await _scroll(tester, 150);
      await tester.tap(find.text('Pleated Midi Skirt'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await _snap(tester, 'item_detail_$suffix');
      await _scroll(tester, 600);
      await _snap(tester, 'item_detail_scrolled_$suffix');
      await tester.tap(find.text('All history'));
      await _snap(tester, 'item_history_$suffix');
      await tester.tap(find.text('Month'));
      await _snap(tester, 'item_history_month_$suffix');
      await _back(tester);
      await _back(tester);

      await _tab(tester, 'Money');
      await _snap(tester, 'money_$suffix');
      await _scroll(tester, 560);
      await _snap(tester, 'money_scrolled_$suffix');
      await _scroll(tester, 600);
      await _snap(tester, 'money_bottom_$suffix');
      await tester.tap(find.text('Money log'));
      await _snap(tester, 'money_log_$suffix');
      await tester.tap(find.text('Month'));
      await _snap(tester, 'money_log_month_$suffix');
      await _back(tester);

      await _tab(tester, 'More');
      await _snap(tester, 'more_$suffix');

      await tester.tap(find.text('Sign Out'));
      await _snap(tester, 'sign_out_sheet_$suffix');
      await tester.tap(find.descendant(of: find.byType(CupertinoActionSheet), matching: find.text('Sign Out')));
      await _snap(tester, 'sign_in_$suffix');
      await tester.enterText(find.widgetWithText(CupertinoTextField, 'Email'), 'ana@skirtandtee.ph');
      await tester.pump();
      await tester.tap(find.widgetWithText(CupertinoButton, 'Continue'));
      await _snap(tester, 'sign_in_password_$suffix');

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('empty shop snapshots ($suffix)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });

      await tester.pumpWidget((await tester.runAsync(_buildEmptyApp))!);
      await _tab(tester, 'Sales');
      await _snap(tester, 'empty_sales_$suffix');
      await _tab(tester, 'Stock');
      await _snap(tester, 'empty_stock_$suffix');
      await _tab(tester, 'Money');
      await tester.scrollUntilVisible(
        find.text('Money log'),
        200,
        scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
      );
      await _scroll(tester, 300);
      await tester.tap(find.text('Money log'));
      await _snap(tester, 'empty_money_log_$suffix');

      debugDefaultTargetPlatformOverride = null;
    });
  }
}
