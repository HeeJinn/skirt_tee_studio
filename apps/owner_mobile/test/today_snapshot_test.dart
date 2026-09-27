import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/presentation/screens/today/today_snapshot.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import 'package:shop_core/domain/entities/sale.dart';

// Saturday afternoon; "same day last week" is Saturday the 19th.
final now = DateTime(2026, 9, 26, 15);

Sale sale(String id, DateTime at, {double price = 100, int qty = 1, double? cost = 60}) => Sale(
      id: id,
      dateTime: at,
      lineItems: [SaleLineItem(itemId: 'x', itemName: 'Tee', unitPrice: price, qty: qty, unitCost: cost)],
    );

Item item(String name, int qty) => Item(id: name, name: name, category: 'T-Shirt', unitPrice: 100, qtyOnHand: qty);

Reservation pickup(String id, DateTime on, {ReservationStatus status = ReservationStatus.pending}) => Reservation(
      id: id,
      customerName: 'Bea',
      contact: '0917',
      itemId: 'x',
      itemName: 'Tee',
      pickupDate: on,
      status: status,
    );

TodaySnapshot snapshot({
  List<Sale> sales = const [],
  List<Item> items = const [],
  List<Reservation> reservations = const [],
}) =>
    TodaySnapshot.from(sales: sales, items: items, reservations: reservations, lowStockThreshold: 5, now: now);

void main() {
  test('totals today against the same day last week, with gross profit', () {
    final s = snapshot(sales: [
      sale('a', DateTime(2026, 9, 26, 10), price: 300, qty: 2, cost: 120), // ₱600, profit ₱360
      sale('b', DateTime(2026, 9, 26, 14), price: 150, cost: 90), // ₱150, profit ₱60
      sale('c', DateTime(2026, 9, 19, 11), price: 500, cost: 300), // last Saturday: ₱500, profit ₱200
      sale('d', DateTime(2026, 9, 25, 11), price: 999), // yesterday: counts in neither
    ]);

    expect(s.today.revenue, 750);
    expect(s.today.saleCount, 2);
    expect(s.today.itemsSold, 3);
    expect(s.todayGrossProfit, 420);
    expect(s.sameDayLastWeek.revenue, 500);
    expect(s.sameDayLastWeekGrossProfit, 200);
    expect(changeFrom(s.sameDayLastWeek.revenue, s.today.revenue), closeTo(0.5, 1e-9));
  });

  test('nothing to compare against gives no percentage', () {
    expect(changeFrom(0, 750), isNull);
  });

  test('the week chart covers the last 7 days, ending today', () {
    final s = snapshot(sales: [sale('a', DateTime(2026, 9, 26, 10), price: 200)]);

    expect(s.lastSevenDays, hasLength(7));
    expect(s.lastSevenDays.first.date, DateTime(2026, 9, 20));
    expect(s.lastSevenDays.last.date, DateTime(2026, 9, 26));
    expect(s.lastSevenDays.last.amount, 200);
  });

  test('sold-out items are listed apart from low stock', () {
    final s = snapshot(items: [item('Tee', 0), item('Skirt', 3), item('Dress', 5), item('Top', 12)]);

    expect(s.soldOut.map((i) => i.name), ['Tee']);
    expect(s.lowStock.map((i) => i.name), ['Skirt', 'Dress'], reason: 'at or below the threshold of 5');
    expect(s.needsAttention, isTrue);
  });

  test('pickups due today and overdue; picked-up ones are left out', () {
    final s = snapshot(reservations: [
      pickup('today', DateTime(2026, 9, 26)),
      pickup('late', DateTime(2026, 9, 24)),
      pickup('done', DateTime(2026, 9, 24), status: ReservationStatus.pickedUp),
      pickup('later', DateTime(2026, 9, 28)),
    ]);

    expect(s.pickupsDueToday, 1);
    expect(s.pickupsOverdue, 1);
  });

  test('a quiet day needs no attention', () {
    expect(snapshot(items: [item('Top', 12)]).needsAttention, isFalse);
  });

  test('latest sales are the five newest, from any day', () {
    final s = snapshot(sales: [
      for (var d = 20; d <= 26; d++) sale('s$d', DateTime(2026, 9, d, 12)),
    ]);

    expect(s.latestSales.map((x) => x.id), ['s26', 's25', 's24', 's23', 's22']);
  });

  test('flags today\'s pieces with no recorded cost, since profit reads high', () {
    expect(snapshot(sales: [sale('a', DateTime(2026, 9, 26, 10), cost: null)]).hasUncostedSales, isTrue);
    expect(snapshot(sales: [sale('a', DateTime(2026, 9, 26, 10))]).hasUncostedSales, isFalse);
    expect(
      snapshot(sales: [sale('a', DateTime(2026, 9, 25, 10), cost: null)]).hasUncostedSales,
      isFalse,
      reason: 'only today\'s profit is shown',
    );
  });
}
