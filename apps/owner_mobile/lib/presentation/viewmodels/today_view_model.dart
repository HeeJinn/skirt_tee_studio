import 'package:flutter/foundation.dart';
import 'package:shop_core/domain/repositories/item_repository.dart';
import 'package:shop_core/domain/repositories/reservation_repository.dart';
import 'package:shop_core/domain/repositories/sale_repository.dart';
import 'package:shop_core/domain/repositories/settings_repository.dart';

import '../screens/today/today_snapshot.dart';

/// The Today tab's data. Reloaded when the shop computer's changes arrive
/// and on pull-to-refresh; the phone only reads.
class TodayViewModel extends ChangeNotifier {
  TodayViewModel(
    this._sales,
    this._items,
    this._reservations,
    this._settings, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SaleRepository _sales;
  final ItemRepository _items;
  final ReservationRepository _reservations;
  final SettingsRepository _settings;
  final DateTime Function() _clock;

  TodaySnapshot? _snapshot;

  /// Null until the first load finishes.
  TodaySnapshot? get snapshot => _snapshot;

  Future<void> load() async {
    final (sales, items, reservations, threshold) = await (
      _sales.getAll(),
      _items.getAll(),
      _reservations.getAll(),
      _settings.getLowStockThreshold(),
    ).wait;
    _snapshot = TodaySnapshot.from(
      sales: sales,
      items: items,
      reservations: reservations,
      lowStockThreshold: threshold,
      now: _clock(),
    );
    notifyListeners();
  }
}
