import 'package:flutter/cupertino.dart';
import 'package:shop_core/core/theme/app_theme.dart';

/// The shop's theme presets are shared with the desktop app, which builds
/// Material themes from them; the phone builds an iOS theme from the same
/// palettes, so both show the shop's brand color. Colors follow the phone's
/// light/dark setting.
CupertinoThemeData cupertinoThemeFor(ThemePreset preset) => CupertinoThemeData(
      primaryColor: CupertinoDynamicColor.withBrightness(
        color: preset.light.brand,
        darkColor: preset.dark.brand,
      ),
      primaryContrastingColor: CupertinoDynamicColor.withBrightness(
        color: preset.light.onBrand,
        darkColor: preset.dark.onBrand,
      ),
      // iOS's own grouped-list backdrop, like Settings and Wallet.
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    );

/// The shop's theme on the phone. Fixed for now; a picker can come later,
/// as on the desktop.
const kShopPreset = ThemePresets.studioSage;

/// Status and chart colors for the current light/dark mode (success,
/// warning, danger, chart series), checked for contrast in the shared
/// palettes.
AppTokens shopTokens(BuildContext context) =>
    CupertinoTheme.brightnessOf(context) == Brightness.dark ? kShopPreset.dark.tokens : kShopPreset.light.tokens;
