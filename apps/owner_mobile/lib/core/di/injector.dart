import 'package:shop_core/core/config/cloud_config.dart';
import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:shop_core/data/datasources/local/item_image_storage.dart';
import 'package:shop_core/data/sync/cloud_sync_repository_impl.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

/// Composition root: wires shop_core's data layer to the app's ViewModels,
/// the same manual-DI approach as the desktop app.
class Injector {
  Injector._({required this.cloudSyncViewModel});

  final CloudSyncViewModel cloudSyncViewModel;

  static Future<Injector> create() async {
    final db = await DatabaseService.instance.database;
    await ItemImageStorage.instance.init();

    final cloudSyncViewModel = CloudSyncViewModel(
      CloudSyncRepositoryImpl(
        db,
        CloudConfig.fromEnvironment,
        // The phone joins the shop the shop computer created, never makes
        // one, and doesn't keep the shop's data after signing out.
        createShopIfMissing: false,
        clearLocalDataOnSignOut: true,
      ),
      // No screens show shop data yet.
      onRemoteChanges: () async {},
    );
    await cloudSyncViewModel.load();

    return Injector._(cloudSyncViewModel: cloudSyncViewModel);
  }
}
