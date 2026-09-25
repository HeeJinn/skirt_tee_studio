import '../../domain/entities/appearance.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/local/settings_local_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._localDataSource);
  final SettingsLocalDataSource _localDataSource;

  @override
  Future<int> getLowStockThreshold() async =>
      await _localDataSource.getLowStockThreshold() ?? SettingsRepository.defaultLowStockThreshold;

  @override
  Future<void> setLowStockThreshold(int value) => _localDataSource.setLowStockThreshold(value);

  @override
  Future<String?> getThemePresetId() => _localDataSource.getThemePresetId();

  @override
  Future<void> setThemePresetId(String id) => _localDataSource.setThemePresetId(id);

  @override
  Future<AppearanceMode> getAppearanceMode() async {
    final stored = await _localDataSource.getAppearanceMode();
    return AppearanceMode.values.asNameMap()[stored] ?? AppearanceMode.system;
  }

  @override
  Future<void> setAppearanceMode(AppearanceMode mode) => _localDataSource.setAppearanceMode(mode.name);
}
