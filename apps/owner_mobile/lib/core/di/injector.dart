import 'package:shop_core/core/config/cloud_config.dart';
import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:shop_core/data/datasources/local/item_image_storage.dart';
import 'package:shop_core/data/datasources/local/item_local_data_source.dart';
import 'package:shop_core/data/datasources/local/reservation_local_data_source.dart';
import 'package:shop_core/data/datasources/local/sale_local_data_source.dart';
import 'package:shop_core/data/datasources/local/settings_local_data_source.dart';
import 'package:shop_core/data/repositories/item_repository_impl.dart';
import 'package:shop_core/data/repositories/reservation_repository_impl.dart';
import 'package:shop_core/data/repositories/sale_repository_impl.dart';
import 'package:shop_core/data/repositories/settings_repository_impl.dart';
import 'package:shop_core/data/sync/cloud_sync_repository_impl.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../presentation/viewmodels/today_view_model.dart';

/// Composition root: wires shop_core's data layer to the app's ViewModels,
/// the same manual-DI approach as the desktop app.
class Injector {
  Injector._({required this.cloudSyncViewModel, required this.todayViewModel});

  final CloudSyncViewModel cloudSyncViewModel;
  final TodayViewModel todayViewModel;

  static Future<Injector> create() async {
    final db = await DatabaseService.instance.database;
    await ItemImageStorage.instance.init();

    final todayViewModel = TodayViewModel(
      SaleRepositoryImpl(SaleLocalDataSourceImpl(db)),
      ItemRepositoryImpl(ItemLocalDataSourceImpl(db)),
      ReservationRepositoryImpl(ReservationLocalDataSourceImpl(db)),
      SettingsRepositoryImpl(SettingsLocalDataSourceImpl(db)),
    );

    // Everything that shows shop data, reloaded when the shop computer's
    // changes arrive.
    Future<void> loadShopData() => todayViewModel.load();

    final cloudSyncViewModel = CloudSyncViewModel(
      CloudSyncRepositoryImpl(
        db,
        CloudConfig.fromEnvironment,
        // The phone joins the shop the shop computer created, never makes
        // one, and doesn't keep the shop's data after signing out.
        createShopIfMissing: false,
        clearLocalDataOnSignOut: true,
      ),
      onRemoteChanges: loadShopData,
    );

    // Signing out empties the phone; drop what the screens were showing.
    var wasSignedOut = true;
    cloudSyncViewModel.addListener(() {
      final signedOut = cloudSyncViewModel.state.status == CloudStatus.signedOut;
      if (signedOut && !wasSignedOut) loadShopData();
      wasSignedOut = signedOut;
    });

    await Future.wait([cloudSyncViewModel.load(), loadShopData()]);

    return Injector._(cloudSyncViewModel: cloudSyncViewModel, todayViewModel: todayViewModel);
  }
}
