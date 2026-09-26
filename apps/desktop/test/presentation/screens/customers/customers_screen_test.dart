import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import 'package:skirt_tee_studio/presentation/screens/customers/customers_screen.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/reservation_view_model.dart';

import '../../../fakes/fake_reservation_repository.dart';
import '../../../fakes/fake_sale_repository.dart';

Widget _buildApp(ReservationViewModel viewModel) {
  return ChangeNotifierProvider.value(
    value: viewModel,
    child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: CustomersScreen())),
  );
}

void main() {
  testWidgets('shows a grouped customer row and expands to reservation history', (tester) async {
    final viewModel = ReservationViewModel(FakeReservationRepository(), FakeSaleRepository());
    await viewModel.addReservation(Reservation(
      id: '1',
      customerName: 'Maria Cruz',
      contact: '0917 000 0000',
      itemId: 'item-1',
      itemName: 'Basic Tee',
      pickupDate: DateTime(2026, 1, 5),
    ));
    await viewModel.addReservation(Reservation(
      id: '2',
      customerName: 'Maria Cruz',
      contact: '0917 000 0000',
      itemId: 'item-2',
      itemName: 'Denim Skirt',
      pickupDate: DateTime(2026, 2, 10),
      status: ReservationStatus.pickedUp,
    ));

    await tester.pumpWidget(_buildApp(viewModel));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Maria Cruz'), findsOneWidget);
    expect(find.text('2 reservations'), findsOneWidget);
    expect(find.text('Basic Tee'), findsNothing); // collapsed by default

    await tester.tap(find.text('Maria Cruz'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Basic Tee'), findsOneWidget);
    expect(find.textContaining('Denim Skirt'), findsOneWidget);
  });

  testWidgets('search filters by name or contact', (tester) async {
    final viewModel = ReservationViewModel(FakeReservationRepository(), FakeSaleRepository());
    await viewModel.addReservation(Reservation(
      id: '1',
      customerName: 'Ana Reyes',
      contact: 'fb:ana',
      itemId: 'item-1',
      itemName: 'Basic Tee',
      pickupDate: DateTime(2026, 1, 1),
    ));
    await viewModel.addReservation(Reservation(
      id: '2',
      customerName: 'Bea Santos',
      contact: 'fb:bea',
      itemId: 'item-1',
      itemName: 'Basic Tee',
      pickupDate: DateTime(2026, 1, 2),
    ));

    await tester.pumpWidget(_buildApp(viewModel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ana Reyes'), findsOneWidget);
    expect(find.text('Bea Santos'), findsNothing);
  });
}
