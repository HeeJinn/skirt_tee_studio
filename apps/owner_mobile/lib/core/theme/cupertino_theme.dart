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

/// Status colors for the current light/dark mode (success, warning,
/// danger), checked for contrast in the shared palettes.
AppTokens shopTokens(BuildContext context, ThemePreset preset) =>
    CupertinoTheme.brightnessOf(context) == Brightness.dark ? preset.dark.tokens : preset.light.tokens;
