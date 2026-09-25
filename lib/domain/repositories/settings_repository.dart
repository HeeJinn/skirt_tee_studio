import '../entities/appearance.dart';

abstract class SettingsRepository {
  /// The threshold used before any value has ever been saved — matches the
  /// original hardcoded MVP threshold.
  static const defaultLowStockThreshold = 5;

  Future<int> getLowStockThreshold();
  Future<void> setLowStockThreshold(int value);

  /// Null when never chosen — the presentation layer owns the preset list
  /// and its default.
  Future<String?> getThemePresetId();
  Future<void> setThemePresetId(String id);

  Future<AppearanceMode> getAppearanceMode();
  Future<void> setAppearanceMode(AppearanceMode mode);
}
