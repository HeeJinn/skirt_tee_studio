import 'package:flutter/cupertino.dart';
import 'package:shop_core/core/theme/app_theme.dart';

/// The shop's theme presets are shared with the desktop app, which builds
/// Material themes from them; the phone builds an iOS theme from the same
/// palettes, so both show the shop's brand. Colors follow the phone's
/// light/dark setting.
CupertinoThemeData cupertinoThemeFor(ThemePreset preset) {
  final light = preset.light;
  final dark = preset.dark;
  Color both(Color l, Color d) => CupertinoDynamicColor.withBrightness(color: l, darkColor: d);

  // Light: a faintly sage page under white cards. Dark: the palette's own
  // deepest tone.
  final page = both(light.tokens.sunken, dark.bg);
  final ink = both(light.ink, dark.ink);

  const base = CupertinoTextThemeData();
  return CupertinoThemeData(
    primaryColor: both(light.brand, dark.brand),
    primaryContrastingColor: both(light.onBrand, dark.onBrand),
    scaffoldBackgroundColor: page,
    // Bars take the page's color, slightly see-through, so content scrolling
    // under them blurs rather than cutting off at a white strip.
    barBackgroundColor: both(
      light.tokens.sunken.withValues(alpha: 0.92),
      dark.bg.withValues(alpha: 0.92),
    ),
    textTheme: CupertinoTextThemeData(
      primaryColor: both(light.brand, dark.brand),
      textStyle: base.textStyle.copyWith(color: ink),
      // Large titles in Georgia, like the shop computer's screen titles.
      navLargeTitleTextStyle: base.navLargeTitleTextStyle.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: ink,
      ),
      navTitleTextStyle: base.navTitleTextStyle.copyWith(color: ink),
    ),
  );
}

/// The shop's theme on the phone. Fixed for now; a picker can come later,
/// as on the desktop.
const kShopPreset = ThemePresets.studioSage;

/// Status and chart colors for the current light/dark mode (success,
/// warning, danger, chart series), checked for contrast in the shared
/// palettes.
AppTokens shopTokens(BuildContext context) =>
    CupertinoTheme.brightnessOf(context) == Brightness.dark ? kShopPreset.dark.tokens : kShopPreset.light.tokens;
