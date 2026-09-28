import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/domain/entities/item.dart';

void main() {
  Item tee({bool onSale = false, double? percent, double? price}) => Item(
        id: 'tee',
        name: 'Basic Tee',
        category: 'T-Shirt',
        unitPrice: 249,
        qtyOnHand: 5,
        onSale: onSale,
        salePercent: percent,
        salePrice: price,
      );

  test('not on sale, it sells at the regular price', () {
    expect(tee().sellingPrice, 249);
    expect(tee().isMarkedDown, isFalse);
    expect(tee().percentOff, isNull);
  });

  test('a percent off rounds to the whole peso', () {
    final item = tee(onSale: true, percent: 20); // 199.20
    expect(item.sellingPrice, 199);
    expect(item.percentOff, 20);
  });

  test('a set sale price is used as is, and reports what it takes off', () {
    final item = tee(onSale: true, price: 150);
    expect(item.sellingPrice, 150);
    expect(item.percentOff, 40);
  });

  test('a sale discount is ignored once the sale is off', () {
    expect(tee(percent: 20).sellingPrice, 249);
  });

  test('an old Bargain tag with no discount keeps the regular price', () {
    final item = tee(onSale: true);
    expect(item.sellingPrice, 249);
    expect(item.isMarkedDown, isFalse);
  });

  test('copyWith keeps the sale', () {
    final item = tee(onSale: true, percent: 20).copyWith(qtyOnHand: 1);
    expect(item.sellingPrice, 199);
  });
}
