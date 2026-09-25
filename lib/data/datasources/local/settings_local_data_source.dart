import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract class SettingsLocalDataSource {
  /// Null when never set — caller decides the default.
  Future<int?> getLowStockThreshold();
  Future<void> setLowStockThreshold(int value);

  Future<String?> getThemePresetId();
  Future<void> setThemePresetId(String id);

  /// Stored as the enum's name; null when never set.
  Future<String?> getAppearanceMode();
  Future<void> setAppearanceMode(String mode);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  SettingsLocalDataSourceImpl(this._db);
  final Database _db;

  static const _lowStockKey = 'lowStockThreshold';
  static const _themePresetKey = 'themePreset';
  static const _appearanceModeKey = 'appearanceMode';

  Future<String?> _get(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.single['value'] as String;
  }

  Future<void> _set(String key, String value) => _db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<int?> getLowStockThreshold() async {
    final value = await _get(_lowStockKey);
    return value == null ? null : int.tryParse(value);
  }

  @override
  Future<void> setLowStockThreshold(int value) => _set(_lowStockKey, '$value');

  @override
  Future<String?> getThemePresetId() => _get(_themePresetKey);

  @override
  Future<void> setThemePresetId(String id) => _set(_themePresetKey, id);

  @override
  Future<String?> getAppearanceMode() => _get(_appearanceModeKey);

  @override
  Future<void> setAppearanceMode(String mode) => _set(_appearanceModeKey, mode);
}
