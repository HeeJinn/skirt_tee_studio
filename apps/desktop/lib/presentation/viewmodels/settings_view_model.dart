import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/theme_presets.dart';
import 'package:shop_core/domain/entities/appearance.dart';
import 'package:shop_core/domain/repositories/settings_repository.dart';

import '../../core/constants/categories.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._repository);
  final SettingsRepository _repository;

  int _lowStockThreshold = SettingsRepository.defaultLowStockThreshold;
  int get lowStockThreshold => _lowStockThreshold;

  List<String> _categories = SettingsRepository.defaultCategories;

  /// The owners' category list, in their order. Screens offer
  /// categoryOptions(categories, items), which adds any an item still uses.
  List<String> get categories => List.unmodifiable(_categories);

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
    _categories = await _repository.getCategories();
    _themePreset = ThemePresets.byId(await _repository.getThemePresetId());
    _appearanceMode = await _repository.getAppearanceMode();
    notifyListeners();
  }

  Future<void> updateLowStockThreshold(int value) async {
    await _repository.setLowStockThreshold(value);
    _lowStockThreshold = value;
    notifyListeners();
  }

  Future<void> saveCategories(List<String> categories) async {
    await _repository.setCategories(categories);
    _categories = List.of(categories);
    notifyListeners();
  }

  /// Saves any of [names] not on the list yet (ignoring case) — a category
  /// typed while adding an item joins the list for next time.
  Future<void> addCategories(Iterable<String> names) async {
    final updated = [..._categories];
    for (final name in names) {
      if (name.trim().isNotEmpty && findCategory(updated, name) == null) updated.add(name.trim());
    }
    if (updated.length == _categories.length) return;
    await saveCategories(updated);
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
