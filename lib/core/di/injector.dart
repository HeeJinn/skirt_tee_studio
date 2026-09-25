import '../../data/datasources/local/database_service.dart';
import '../../data/datasources/local/item_local_data_source.dart';
import '../../data/datasources/local/reservation_local_data_source.dart';
import '../../data/datasources/local/sale_local_data_source.dart';
import '../../data/datasources/local/settings_local_data_source.dart';
import '../../data/repositories/item_repository_impl.dart';
import '../../data/repositories/money_repository_impl.dart';
import '../../data/repositories/reservation_repository_impl.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/staff_repository_impl.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../presentation/viewmodels/cart_view_model.dart';
import '../../presentation/viewmodels/inventory_view_model.dart';
import '../../presentation/viewmodels/money_view_model.dart';
import '../../presentation/viewmodels/reservation_view_model.dart';
import '../../presentation/viewmodels/sales_view_model.dart';
import '../../presentation/viewmodels/session_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';

/// Composition root: wires data sources -> repositories -> ViewModels.
/// Manual DI is deliberate here (matches the project's "deliberately
/// minimal packages" approach) rather than pulling in a service locator.
class Injector {
  Injector._({
    required this.inventoryViewModel,
    required this.cartViewModel,
    required this.reservationViewModel,
    required this.salesViewModel,
    required this.settingsViewModel,
    required this.sessionViewModel,
    required this.moneyViewModel,
  });

  final InventoryViewModel inventoryViewModel;
  final CartViewModel cartViewModel;
  final ReservationViewModel reservationViewModel;
  final SalesViewModel salesViewModel;
  final SettingsViewModel settingsViewModel;
  final SessionViewModel sessionViewModel;
  final MoneyViewModel moneyViewModel;

  static Future<Injector> create() async {
    final db = await DatabaseService.instance.database;

    final itemRepository = ItemRepositoryImpl(ItemLocalDataSourceImpl(db));
    final saleRepository = SaleRepositoryImpl(SaleLocalDataSourceImpl(db));
    final reservationRepository =
        ReservationRepositoryImpl(ReservationLocalDataSourceImpl(db));
    final settingsRepository = SettingsRepositoryImpl(SettingsLocalDataSourceImpl(db));
    final stockRepository = StockRepositoryImpl(db);

    final inventoryViewModel = InventoryViewModel(itemRepository, stockRepository);
    final reservationViewModel = ReservationViewModel(reservationRepository, saleRepository);
    final salesViewModel = SalesViewModel(saleRepository);
    final settingsViewModel = SettingsViewModel(settingsRepository);
    final sessionViewModel = SessionViewModel(StaffRepositoryImpl(db));
    final moneyViewModel = MoneyViewModel(MoneyRepositoryImpl(db), stockRepository);
    await Future.wait([
      inventoryViewModel.load(),
      reservationViewModel.load(),
      salesViewModel.load(),
      settingsViewModel.load(),
      sessionViewModel.load(),
      moneyViewModel.load(),
    ]);

    return Injector._(
      inventoryViewModel: inventoryViewModel,
      cartViewModel: CartViewModel(saleRepository),
      reservationViewModel: reservationViewModel,
      salesViewModel: salesViewModel,
      settingsViewModel: settingsViewModel,
      sessionViewModel: sessionViewModel,
      moneyViewModel: moneyViewModel,
    );
  }
}
