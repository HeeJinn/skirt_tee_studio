import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/data/datasources/local/settings_local_data_source.dart';

import '../../../test_helpers.dart';

void main() {
  late SettingsLocalDataSourceImpl dataSource;

  setUp(() async {
    dataSource = SettingsLocalDataSourceImpl(await openTestDatabase());
  });

  test('getLowStockThreshold is null before anything is saved', () async {
    expect(await dataSource.getLowStockThreshold(), isNull);
  });

  test('setLowStockThreshold then getLowStockThreshold round-trips the value', () async {
    await dataSource.setLowStockThreshold(8);

    expect(await dataSource.getLowStockThreshold(), 8);
  });

  test('setLowStockThreshold overwrites the previous value', () async {
    await dataSource.setLowStockThreshold(8);
    await dataSource.setLowStockThreshold(3);

    expect(await dataSource.getLowStockThreshold(), 3);
  });

  test('theme preset and appearance mode are null until saved, then round-trip', () async {
    expect(await dataSource.getThemePresetId(), isNull);
    expect(await dataSource.getAppearanceMode(), isNull);

    await dataSource.setThemePresetId('slate_cobalt');
    await dataSource.setAppearanceMode('dark');

    expect(await dataSource.getThemePresetId(), 'slate_cobalt');
    expect(await dataSource.getAppearanceMode(), 'dark');
  });

  test('theme settings do not disturb the low-stock threshold', () async {
    await dataSource.setLowStockThreshold(8);
    await dataSource.setThemePresetId('blush_atelier');

    expect(await dataSource.getLowStockThreshold(), 8);
  });
}
