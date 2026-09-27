// One-off dev seed: sample items and their purchase batches (stock lots),
// then a full history on top of them — daily sales from the first batch up
// to now, the owners' money log (money put in, monthly expenses, money
// taken home) and a few stock losses — so Sales, Reports and Money all have
// something to show on every range up to "All time".
//
//   flutter test tool/seed_sample_data.dart
//
// Safe to re-run: items that already exist (by name) aren't re-created or
// re-stocked, and the history is skipped once its money entries are there.
//
// Writes straight to the real app database (same file main.dart opens), so
// PowerSync queues these rows for upload the next time the app connects to
// the cloud.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:shop_core/data/datasources/local/sale_local_data_source.dart';
import 'package:shop_core/data/datasources/local/sql_helpers.dart';
import 'package:shop_core/data/repositories/money_repository_impl.dart';
import 'package:shop_core/data/repositories/sale_repository_impl.dart';
import 'package:shop_core/data/repositories/stock_repository_impl.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/entities/stock.dart';

const _uuid = Uuid();

/// Marks the seeded money entries, so a re-run can tell it already ran.
const _sampleNote = 'Sample data';

/// One category+price combo ("batch category") and the purchase batches
/// that stocked it, oldest first.
class _SeedLine {
  const _SeedLine(this.category, this.price, this.batches);
  final String category;
  final double price;
  final List<(DateTime at, int qty)> batches;

  String get name => '$category ${price.toStringAsFixed(0)}';
}

// From the shop's logbook. Entries with no price yet (Bargain, and the
// other "TBD" rows) are left out — nothing to seed until a price is set.
final _seedLines = [
  _SeedLine('Skirt', 159, [(DateTime(2026, 7, 10), 18), (DateTime(2026, 8, 24), 14)]),
  _SeedLine('T-Shirt', 249, [(DateTime(2026, 7, 3), 40), (DateTime(2026, 8, 5), 30), (DateTime(2026, 9, 10), 25)]),
  _SeedLine('T-Shirt', 299, [(DateTime(2026, 7, 14), 28), (DateTime(2026, 8, 19), 22)]),
  _SeedLine('T-Shirt', 349, [(DateTime(2026, 7, 8), 32), (DateTime(2026, 8, 15), 24), (DateTime(2026, 9, 18), 20)]),
  _SeedLine('T-Shirt', 499, [(DateTime(2026, 7, 22), 14), (DateTime(2026, 8, 30), 10)]),
  _SeedLine('Long Sleeves', 399, [(DateTime(2026, 7, 12), 16), (DateTime(2026, 8, 21), 12)]),
  _SeedLine('Kids', 199, [(DateTime(2026, 7, 17), 22), (DateTime(2026, 8, 27), 18)]),
];

/// The shop opened with its first batch; the books start the day before.
final _opened = DateTime(2026, 7, 1);

void main() {
  test('seed sample data', () async {
    // Hardcoded rather than resolved via path_provider: plugins aren't
    // registered under `flutter test`, so getApplicationSupportDirectory()
    // isn't reliable here. This is the path main.dart resolves to on this
    // machine (checked directly against the live app data folder).
    // SEED_DB points it at a copy instead, to try it out first.
    final path = Platform.environment['SEED_DB'] ??
        r'C:\Users\wardog\AppData\Roaming\com.example\skirt_tee_studio\skirt_tee_studio_cloud.db';
    final db = await DatabaseService.openAt(path);
    final stockRepo = StockRepositoryImpl(db);

    // --- Items and their purchase batches ---
    final itemIds = <_SeedLine, String>{};
    for (final line in _seedLines) {
      final existing = await db.query('items', columns: ['id'], where: 'name = ?', whereArgs: [line.name]);
      if (existing.isNotEmpty) {
        itemIds[line] = existing.first['id'] as String;
        continue;
      }
      final item = Item(id: _uuid.v4(), name: line.name, category: line.category, unitPrice: line.price, qtyOnHand: 0);
      itemIds[line] = item.id;
      // Overruns typically cost ~55% of what they sell for.
      final unitCost = (line.price * 0.55).roundToDouble();
      for (var i = 0; i < line.batches.length; i++) {
        final (at, qty) = line.batches[i];
        await stockRepo.receiveLot(
          StockLot(id: _uuid.v4(), at: at, supplier: 'Bulk supplier', itemsCost: unitCost * qty),
          [LotLine(itemId: item.id, itemName: item.name, qty: qty, sellingPrice: line.price)],
          newItems: i == 0 ? [item] : const [],
        );
      }
    }

    final alreadySeeded = await db.query('money_entries', columns: ['id'], where: 'note = ?', whereArgs: [_sampleNote]);
    if (alreadySeeded.isNotEmpty) {
      await db.close();
      return;
    }

    // Profit and payback only count from the books' start, so it has to
    // reach back over the sample history.
    final booksStart = await MoneyRepositoryImpl(db).booksStartedAtIfSet();
    if (booksStart == null || booksStart.isAfter(_opened)) {
      await db.upsert('shop_settings', DatabaseService.booksStartedAtKey, {'value': _opened.toIso8601String()});
    }

    final random = Random(42);
    final now = DateTime.now();

    // --- Sales, every day from the first batch to now ---
    // Never sells more than had arrived by that day, nor more than is on
    // the shelf now (real POS sales may already have taken some).
    final onHand = <_SeedLine, int>{};
    for (final line in _seedLines) {
      final row = await db.query('items', columns: ['qtyOnHand'], where: 'id = ?', whereArgs: [itemIds[line]]);
      onHand[line] = row.single['qtyOnHand'] as int;
    }
    final sold = {for (final line in _seedLines) line: 0};
    int available(_SeedLine line, DateTime day) {
      final arrived = line.batches.where((b) => !b.$1.isAfter(day)).fold(0, (sum, b) => sum + b.$2);
      return min(arrived, onHand[line]!) - sold[line]!;
    }

    final saleRepo = SaleRepositoryImpl(SaleLocalDataSourceImpl(db));
    final walletSales = <DateTime, double>{}; // month → GCash/Maya/card takings, for the fees
    for (var day = DateTime(2026, 7, 3); !day.isAfter(now); day = DateTime(day.year, day.month, day.day + 1)) {
      final weekend = day.weekday >= DateTime.saturday;
      final count = weekend ? 2 + random.nextInt(3) : random.nextInt(3);
      final times = [
        for (var i = 0; i < count; i++) day.add(Duration(hours: 10, minutes: random.nextInt(10 * 60))),
      ]..sort();

      for (final at in times.where((t) => t.isBefore(now))) {
        final lines = <SaleLineItem>[];
        for (var n = 1 + (random.nextDouble() < 0.3 ? 1 : 0); n > 0; n--) {
          final inStock = _seedLines.where((l) => available(l, day) > 0 && !lines.any((s) => s.itemId == itemIds[l]));
          if (inStock.isEmpty) break;
          final line = inStock.elementAt(random.nextInt(inStock.length));
          final qty = min(available(line, day), random.nextDouble() < 0.2 ? 2 : 1);
          sold[line] = sold[line]! + qty;
          lines.add(SaleLineItem(itemId: itemIds[line]!, itemName: line.name, unitPrice: line.price, qty: qty));
        }
        if (lines.isEmpty) continue;

        final total = lines.fold(0.0, (sum, l) => sum + l.subtotal);
        final roll = random.nextDouble();
        final method = roll < 0.55
            ? PaymentMethod.cash
            : roll < 0.85
                ? PaymentMethod.gcash
                : roll < 0.93
                    ? PaymentMethod.maya
                    : PaymentMethod.card;
        double? tendered;
        if (method == PaymentMethod.cash) {
          final note = [total, 100, 500, 1000][random.nextInt(4)].toDouble();
          tendered = (total / note).ceil() * note;
        } else {
          walletSales.update(DateTime(at.year, at.month), (v) => v + total, ifAbsent: () => total);
        }
        await saleRepo.recordSale(
          Sale(id: _uuid.v4(), dateTime: at, lineItems: lines, paymentMethod: method, amountTendered: tendered),
        );
      }
    }

    // --- Money log ---
    final ownerRows = await db.query('staff', columns: ['name'], where: 'role = ?', whereArgs: ['owner'], orderBy: 'name');
    final owners = [for (final r in ownerRows) r['name'] as String];
    String? owner(int i) => owners.isEmpty ? null : owners[i % owners.length];
    double around(double base, double spread) => (base + (random.nextDouble() * 2 - 1) * spread).roundToDouble();

    final entries = <MoneyEntry>[];
    void add(DateTime at, MoneyEntryKind kind, double amount,
        {ExpenseCategory? category, PaidFrom paidFrom = PaidFrom.shop, String? person, String note = ''}) {
      if (!at.isBefore(now)) return;
      entries.add(MoneyEntry(
        id: _uuid.v4(),
        at: at,
        kind: kind,
        amount: amount,
        category: category,
        paidFrom: paidFrom,
        person: person,
        note: note.isEmpty ? _sampleNote : '$note · $_sampleNote',
      ));
    }

    // Start-up money covers the July batches and the first month's rent.
    if (owners.length > 1) {
      add(_opened, MoneyEntryKind.capitalIn, 25000, person: owner(0), note: 'Start-up money');
      add(_opened, MoneyEntryKind.capitalIn, 15000, person: owner(1), note: 'Start-up money');
    } else {
      add(_opened, MoneyEntryKind.capitalIn, 40000, person: owner(0), note: 'Start-up money');
    }

    for (var month = _opened; !month.isAfter(now); month = DateTime(month.year, month.month + 1)) {
      DateTime on(int day) => DateTime(month.year, month.month, day, 9);
      final first = month == _opened;
      add(on(1), MoneyEntryKind.expense, 5000,
          category: ExpenseCategory.rent,
          paidFrom: first ? PaidFrom.owners : PaidFrom.shop,
          person: first ? owner(0) : null,
          note: 'Stall rent');
      add(on(5), MoneyEntryKind.expense, around(650, 150), category: ExpenseCategory.packaging, note: 'Paper bags & tags');
      add(on(10), MoneyEntryKind.expense, around(600, 200), category: ExpenseCategory.marketing, note: 'Facebook ads');
      add(on(15), MoneyEntryKind.expense, around(900, 200), category: ExpenseCategory.utilities, note: 'Electricity');
      add(on(20), MoneyEntryKind.expense, around(250, 80), category: ExpenseCategory.delivery, note: 'Lalamove to supplier');
      if (!first) {
        add(on(25), MoneyEntryKind.ownerDraw, 2500, person: owner(0));
        if (owners.length > 1) add(on(25), MoneyEntryKind.ownerDraw, 2500, person: owner(1));
      }
      // E-wallet and card fees land once the month is over.
      final monthEnd = DateTime(month.year, month.month + 1, 0, 18);
      final wallet = walletSales[month] ?? 0;
      if (wallet > 0) {
        add(monthEnd, MoneyEntryKind.expense, (wallet * 0.015).roundToDouble(),
            category: ExpenseCategory.fees, note: 'GCash, Maya & card fees');
      }
    }
    final moneyRepo = MoneyRepositoryImpl(db);
    for (final e in entries) {
      await moneyRepo.add(e);
    }

    // --- A few losses, so Reports' shrinkage isn't empty ---
    final losses = [
      (_seedLines[1], DateTime(2026, 7, 28, 17), WriteOffReason.damaged, 'Stain that won\'t wash out'),
      (_seedLines[0], DateTime(2026, 8, 16, 19), WriteOffReason.lost, 'Missing after a busy Saturday'),
      (_seedLines[3], DateTime(2026, 9, 7, 12), WriteOffReason.givenAway, 'Raffle prize'),
      (_seedLines[2], DateTime(2026, 9, 21, 18), WriteOffReason.countShort, 'Monthly count'),
    ];
    for (final (line, at, reason, note) in losses) {
      if (at.isBefore(now) && onHand[line]! - sold[line]! > 0) {
        await stockRepo.writeOff(itemIds[line]!, 1, reason, note: note, at: at);
      }
    }

    await db.close();
  });
}
