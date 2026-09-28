import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/core/theme/theme_presets.dart';
import 'package:shop_core/domain/entities/appearance.dart';
import 'package:shop_core/domain/repositories/settings_repository.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/settings_view_model.dart';

import 'package:shop_core/testing/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;
  late SettingsViewModel viewModel;

  setUp(() {
    repository = FakeSettingsRepository();
    viewModel = SettingsViewModel(repository);
  });

  test('lowStockThreshold defaults before load', () {
    expect(viewModel.lowStockThreshold, SettingsRepository.defaultLowStockThreshold);
  });

  test('load reflects a previously saved threshold', () async {
    await repository.setLowStockThreshold(10);

    await viewModel.load();

    expect(viewModel.lowStockThreshold, 10);
  });

  test('updateLowStockThreshold persists and updates immediately', () async {
    await viewModel.updateLowStockThreshold(2);

    expect(viewModel.lowStockThreshold, 2);
    expect(await repository.getLowStockThreshold(), 2);
  });

  test('categories start from the defaults and load what was saved', () async {
    expect(viewModel.categories, SettingsRepository.defaultCategories);
    await repository.setCategories(['Tops', 'Bottoms']);

    await viewModel.load();

    expect(viewModel.categories, ['Tops', 'Bottoms']);
  });

  test('addCategories saves only names not already on the list, ignoring case', () async {
    await viewModel.addCategories(['long sleeves', 'Dress', ' dress ', '']);

    expect(viewModel.categories, [...SettingsRepository.defaultCategories, 'Dress']);
    expect(await repository.getCategories(), viewModel.categories);
  });

  test('theme defaults to Studio Sage following the system mode', () {
    expect(viewModel.themePreset, ThemePresets.studioSage);
    expect(viewModel.appearanceMode, AppearanceMode.system);
    expect(viewModel.themeMode, ThemeMode.system);
  });

  test('load restores a saved preset and mode', () async {
    await repository.setThemePresetId(ThemePresets.blushAtelier.id);
    await repository.setAppearanceMode(AppearanceMode.dark);

    await viewModel.load();

    expect(viewModel.themePreset, ThemePresets.blushAtelier);
    expect(viewModel.themeMode, ThemeMode.dark);
  });

  test('load falls back to the default for an unknown preset id', () async {
    await repository.setThemePresetId('retired_theme');

    await viewModel.load();

    expect(viewModel.themePreset, ThemePresets.studioSage);
  });

  test('selectThemePreset notifies and persists', () async {
    var notified = 0;
    viewModel.addListener(() => notified++);

    await viewModel.selectThemePreset(ThemePresets.slateCobalt);

    expect(viewModel.themePreset, ThemePresets.slateCobalt);
    expect(notified, 1);
    expect(await repository.getThemePresetId(), ThemePresets.slateCobalt.id);
  });

  test('selectAppearanceMode persists and maps to ThemeMode', () async {
    await viewModel.selectAppearanceMode(AppearanceMode.light);

    expect(viewModel.themeMode, ThemeMode.light);
    expect(await repository.getAppearanceMode(), AppearanceMode.light);
  });
}
