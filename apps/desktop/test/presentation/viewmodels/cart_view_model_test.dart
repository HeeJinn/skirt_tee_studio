import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/cart_view_model.dart';

import 'package:shop_core/testing/fake_sale_repository.dart';

void main() {
  late FakeSaleRepository repository;
  late CartViewModel viewModel;

  setUp(() {
    repository = FakeSaleRepository();
    viewModel = CartViewModel(repository);
  });

  const item = Item(
    id: '1',
    name: 'Basic Tee',
    category: 'T-Shirt',
    unitPrice: 199,
    qtyOnHand: 2,
  );

  test('addItem is capped at qtyOnHand', () {
    viewModel.addItem(item);
    viewModel.addItem(item);
    viewModel.addItem(item); // beyond stock of 2, should be ignored

    expect(viewModel.qtyInCart(item.id), 2);
  });

  test('total and itemCount reflect the cart', () {
    viewModel.addItem(item);
    viewModel.addItem(item);

    expect(viewModel.total, 398);
    expect(viewModel.itemCount, 2);
  });

  test('decrementItem removes the line at qty 1', () {
    viewModel.addItem(item);
    viewModel.decrementItem(item.id);

    expect(viewModel.isEmpty, isTrue);
  });

  test('checkout on an empty cart does nothing', () async {
    final result = await viewModel.checkout(PaymentMethod.cashless);

    expect(result, isFalse);
    expect(repository.lastRecordedSale, isNull);
  });

  test('checkout records the sale and clears the cart', () async {
    viewModel.addItem(item);
    viewModel.addItem(item);

    final result = await viewModel.checkout(PaymentMethod.cashless);

    expect(result, isTrue);
    expect(viewModel.isEmpty, isTrue);
    expect(repository.lastRecordedSale, isNotNull);
    expect(repository.lastRecordedSale!.totalAmount, 398);
    expect(repository.lastRecordedSale!.lineItems.single.qty, 2);
    expect(repository.lastRecordedSale!.paymentMethod, PaymentMethod.cashless);
  });

  test('an item on sale is charged its sale price', () async {
    const onSale = Item(
      id: '2',
      name: 'Band Tee',
      category: 'T-Shirt',
      unitPrice: 249,
      qtyOnHand: 5,
      onSale: true,
      salePercent: 20,
    );
    viewModel.addItem(onSale);
    viewModel.addItem(onSale);
    expect(viewModel.total, 398);

    await viewModel.checkout(PaymentMethod.cash);

    expect(repository.lastRecordedSale!.lineItems.single.unitPrice, 199);
  });

  test('checkout records the cash handed over, and the change it implies', () async {
    viewModel.addItem(item);

    await viewModel.checkout(PaymentMethod.cash, amountTendered: 500);

    final sale = repository.lastRecordedSale!;
    expect(sale.amountTendered, 500);
    expect(sale.changeGiven, 301);
  });
}
