import 'dart:convert';

import 'package:sqlite_async/sqlite_async.dart';

import 'sql_helpers.dart';

abstract class SettingsLocalDataSource {
  /// Null when never set — caller decides the default.
  Future<int?> getLowStockThreshold();
  Future<void> setLowStockThreshold(int value);

  /// The shop's item categories, in the owners' order. Null when never saved.
  Future<List<String>?> getCategories();
  Future<void> setCategories(List<String> categories);

  Future<String?> getThemePresetId();
  Future<void> setThemePresetId(String id);

  /// Stored as the enum's name; null when never set.
  Future<String?> getAppearanceMode();
  Future<void> setAppearanceMode(String mode);
}

/// The low-stock threshold and categories are shop-wide and sync; the theme and light/dark
/// choice belong to this PC and stay on it.
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  SettingsLocalDataSourceImpl(this._db);
  final SqliteConnection _db;

  static const _shopTable = 'shop_settings';
  static const _deviceTable = 'device_settings';

  static const _lowStockKey = 'lowStockThreshold';
  static const _categoriesKey = 'categories';
  static const _themePresetKey = 'themePreset';
  static const _appearanceModeKey = 'appearanceMode';

  Future<String?> _get(String table, String key) async {
    final rows = await _db.query(table, where: 'id = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.single['value'] as String;
  }

  Future<void> _set(String table, String key, String value) =>
      _db.writeTransaction((txn) => txn.upsert(table, key, {'value': value}));

  @override
  Future<int?> getLowStockThreshold() async {
    final value = await _get(_shopTable, _lowStockKey);
    return value == null ? null : int.tryParse(value);
  }

  @override
  Future<void> setLowStockThreshold(int value) => _set(_shopTable, _lowStockKey, '$value');

  @override
  Future<List<String>?> getCategories() async {
    final value = await _get(_shopTable, _categoriesKey);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    return decoded is List ? decoded.whereType<String>().toList() : null;
  }

  @override
  Future<void> setCategories(List<String> categories) => _set(_shopTable, _categoriesKey, jsonEncode(categories));

  @override
  Future<String?> getThemePresetId() => _get(_deviceTable, _themePresetKey);

  @override
  Future<void> setThemePresetId(String id) => _set(_deviceTable, _themePresetKey, id);

  @override
  Future<String?> getAppearanceMode() => _get(_deviceTable, _appearanceModeKey);

  @override
  Future<void> setAppearanceMode(String mode) => _set(_deviceTable, _appearanceModeKey, mode);
}
