import '../domain/entities/appearance.dart';
import '../domain/repositories/settings_repository.dart';

class FakeSettingsRepository implements SettingsRepository {
  int? _lowStockThreshold;
  String? _themePresetId;
  List<String>? _categories;
  AppearanceMode _appearanceMode = AppearanceMode.system;

  @override
  Future<List<String>> getCategories() async => _categories ?? SettingsRepository.defaultCategories;

  @override
  Future<void> setCategories(List<String> categories) async => _categories = List.of(categories);

  @override
  Future<int> getLowStockThreshold() async =>
      _lowStockThreshold ?? SettingsRepository.defaultLowStockThreshold;

  @override
  Future<void> setLowStockThreshold(int value) async => _lowStockThreshold = value;

  @override
  Future<String?> getThemePresetId() async => _themePresetId;

  @override
  Future<void> setThemePresetId(String id) async => _themePresetId = id;

  @override
  Future<AppearanceMode> getAppearanceMode() async => _appearanceMode;

  @override
  Future<void> setAppearanceMode(AppearanceMode mode) async => _appearanceMode = mode;
}
