import 'package:flutter/material.dart';

import '../../core/theme/theme_presets.dart';
import '../../domain/entities/appearance.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._repository);
  final SettingsRepository _repository;

  int _lowStockThreshold = SettingsRepository.defaultLowStockThreshold;
  int get lowStockThreshold => _lowStockThreshold;

  ThemePreset _themePreset = ThemePresets.studioSage;
  ThemePreset get themePreset => _themePreset;

  AppearanceMode _appearanceMode = AppearanceMode.system;
  AppearanceMode get appearanceMode => _appearanceMode;

  ThemeMode get themeMode => switch (_appearanceMode) {
        AppearanceMode.system => ThemeMode.system,
        AppearanceMode.light => ThemeMode.light,
        AppearanceMode.dark => ThemeMode.dark,
      };

  Future<void> load() async {
    _lowStockThreshold = await _repository.getLowStockThreshold();
    _themePreset = ThemePresets.byId(await _repository.getThemePresetId());
    _appearanceMode = await _repository.getAppearanceMode();
    notifyListeners();
  }

  Future<void> updateLowStockThreshold(int value) async {
    await _repository.setLowStockThreshold(value);
    _lowStockThreshold = value;
    notifyListeners();
  }

  /// Applies immediately, then persists — a theme swap should feel instant.
  Future<void> selectThemePreset(ThemePreset preset) async {
    if (preset.id == _themePreset.id) return;
    _themePreset = preset;
    notifyListeners();
    await _repository.setThemePresetId(preset.id);
  }

  Future<void> selectAppearanceMode(AppearanceMode mode) async {
    if (mode == _appearanceMode) return;
    _appearanceMode = mode;
    notifyListeners();
    await _repository.setAppearanceMode(mode);
  }
}
