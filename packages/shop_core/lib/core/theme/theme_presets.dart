import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The primitives one brightness of a theme is built from. [AppTheme]
/// derives every component style from these, so a preset never touches
/// widget code.
@immutable
class ThemePalette {
  const ThemePalette({
    required this.brightness,
    required this.ink,
    required this.onInk,
    required this.bg,
    required this.mist,
    required this.outline,
    required this.brand,
    required this.onBrand,
    required this.tokens,
  });

  final Brightness brightness;

  /// Neutral text and structure.
  final Color ink;
  final Color onInk;
  final Color bg;

  /// Tinted chrome: the sidebar, sign-in backdrop, monograms.
  final Color mist;
  final Color outline;

  /// The single saturated color — primary buttons, selected chips and nav,
  /// focus rings.
  final Color brand;
  final Color onBrand;
  final AppTokens tokens;
}

/// A named look with a hand-tuned light and dark palette. Dark is designed,
/// not inverted: brand colors lighten and desaturate so they still read on a
/// dark surface.
@immutable
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.blurb,
    required this.light,
    required this.dark,
  });

  /// Persisted in settings — never rename an existing id.
  final String id;
  final String name;
  final String blurb;
  final ThemePalette light;
  final ThemePalette dark;
}

// Status colors keep one meaning across every preset, so they're shared.
const _successLight = Color(0xFF1B7A36);
const _warningLight = Color(0xFF8A5A00);
const _dangerLight = Color(0xFFB3261E);
const _successDark = Color(0xFF6FD08F);
const _warningDark = Color(0xFFE6B450);
const _dangerDark = Color(0xFFFF8A7F);

/// Every palette below was checked for WCAG contrast in both modes: ink,
/// muted text and status colors ≥ 4.5:1 on the background (muted also on
/// sunken and mist), onBrand on brand ≥ 4.5:1, brand on background ≥ 4.5:1,
/// chart series ≥ 3:1. Re-check if you change a value.
class ThemePresets {
  ThemePresets._();

  static const studioSage = ThemePreset(
    id: 'studio_sage',
    name: 'Studio Sage',
    blurb: 'Black ink on pale sage — the shop\'s own logo colors.',
    light: ThemePalette(
      brightness: Brightness.light,
      ink: AppColors.ink,
      onInk: AppColors.surface,
      bg: AppColors.surface,
      mist: AppColors.mistSage,
      outline: AppColors.outline,
      brand: AppColors.ink,
      onBrand: AppColors.surface,
      tokens: AppTokens.light,
    ),
    dark: ThemePalette(
      brightness: Brightness.dark,
      ink: AppColors.darkInk,
      onInk: AppColors.darkBg,
      bg: AppColors.darkBg,
      mist: AppColors.darkMist,
      outline: AppColors.darkOutline,
      brand: AppColors.darkInk,
      onBrand: AppColors.darkBg,
      tokens: AppTokens.dark,
    ),
  );

  static const blushAtelier = ThemePreset(
    id: 'blush_atelier',
    name: 'Blush Atelier',
    blurb: 'Rosy chrome with a raspberry accent — boutique and warm.',
    light: ThemePalette(
      brightness: Brightness.light,
      ink: Color(0xFF2A1418),
      onInk: Color(0xFFFFFCFC),
      bg: Color(0xFFFFFCFC),
      mist: Color(0xFFF6E1E4),
      outline: Color(0xFFE0C3C8),
      brand: Color(0xFFA3224F),
      onBrand: Color(0xFFFFFFFF),
      tokens: AppTokens(
        mutedText: Color(0xFF7A5860),
        sunken: Color(0xFFFBF2F3),
        hairline: Color(0xFFF1E2E4),
        success: _successLight,
        warning: _warningLight,
        danger: _dangerLight,
        accent: Color(0xFF7E3A94),
        chartSeries: Color(0xFFB24A66),
        chartGrid: Color(0xFFF3E6E8),
        chartSales: Color(0xFFC0406A),
        chartCosts: Color(0xFF3F8A83),
      ),
    ),
    dark: ThemePalette(
      brightness: Brightness.dark,
      ink: Color(0xFFF3E9EB),
      onInk: Color(0xFF1A1315),
      bg: Color(0xFF1A1315),
      mist: Color(0xFF2E2226),
      outline: Color(0xFF4A3A3F),
      brand: Color(0xFFFF7FA0),
      onBrand: Color(0xFF1A1315),
      tokens: AppTokens(
        mutedText: Color(0xFFB39DA2),
        sunken: Color(0xFF231A1D),
        hairline: Color(0xFF33272B),
        success: _successDark,
        warning: _warningDark,
        danger: _dangerDark,
        accent: Color(0xFFD9A0EA),
        chartSeries: Color(0xFFF08BA6),
        chartGrid: Color(0xFF2E2427),
        chartSales: Color(0xFFE7668E),
        chartCosts: Color(0xFF4FAEA3),
      ),
    ),
  );

  static const terracottaSand = ThemePreset(
    id: 'terracotta_sand',
    name: 'Terracotta Sand',
    blurb: 'Sand and clay with a teal sale marker — earthy, complementary.',
    light: ThemePalette(
      brightness: Brightness.light,
      ink: Color(0xFF2B211B),
      onInk: Color(0xFFFFFDF9),
      bg: Color(0xFFFFFDF9),
      mist: Color(0xFFEFE4D6),
      outline: Color(0xFFD8C8B4),
      brand: Color(0xFFA94B24),
      onBrand: Color(0xFFFFFFFF),
      tokens: AppTokens(
        mutedText: Color(0xFF6B5B4D),
        sunken: Color(0xFFF8F2EA),
        hairline: Color(0xFFEDE3D6),
        success: _successLight,
        warning: _warningLight,
        danger: _dangerLight,
        accent: Color(0xFF1D6F6A),
        chartSeries: Color(0xFF9C5A3C),
        chartGrid: Color(0xFFECE5DB),
        chartSales: Color(0xFF2E7D6B),
        chartCosts: Color(0xFFC8693A),
      ),
    ),
    dark: ThemePalette(
      brightness: Brightness.dark,
      ink: Color(0xFFF2EBE2),
      onInk: Color(0xFF1A1612),
      bg: Color(0xFF1A1612),
      mist: Color(0xFF2E271F),
      outline: Color(0xFF4A3F33),
      brand: Color(0xFFF08A5D),
      onBrand: Color(0xFF1A1612),
      tokens: AppTokens(
        mutedText: Color(0xFFB3A594),
        sunken: Color(0xFF231E19),
        hairline: Color(0xFF342C24),
        success: _successDark,
        warning: _warningDark,
        danger: _dangerDark,
        accent: Color(0xFF5FC2B6),
        chartSeries: Color(0xFFE09A74),
        chartGrid: Color(0xFF2E2822),
        chartSales: Color(0xFF3FA88F),
        chartCosts: Color(0xFFD98050),
      ),
    ),
  );

  static const slateCobalt = ThemePreset(
    id: 'slate_cobalt',
    name: 'Slate & Cobalt',
    blurb: 'Cool slate neutrals and a crisp cobalt — clean, product-like.',
    light: ThemePalette(
      brightness: Brightness.light,
      ink: Color(0xFF0F172A),
      onInk: Color(0xFFFFFFFF),
      bg: Color(0xFFFFFFFF),
      mist: Color(0xFFE2E8F0),
      outline: Color(0xFFCBD5E1),
      brand: Color(0xFF2F55D4),
      onBrand: Color(0xFFFFFFFF),
      tokens: AppTokens(
        mutedText: Color(0xFF526071),
        sunken: Color(0xFFF1F5F9),
        hairline: Color(0xFFE5E9F0),
        success: _successLight,
        warning: _warningLight,
        danger: _dangerLight,
        accent: Color(0xFFC2410C),
        chartSeries: Color(0xFF3B5BDB),
        chartGrid: Color(0xFFE6EAF0),
        chartSales: Color(0xFF2563C9),
        chartCosts: Color(0xFFD9822B),
      ),
    ),
    dark: ThemePalette(
      brightness: Brightness.dark,
      ink: Color(0xFFE6EAF2),
      onInk: Color(0xFF0E1320),
      bg: Color(0xFF0E1320),
      mist: Color(0xFF1C2436),
      outline: Color(0xFF334055),
      brand: Color(0xFF8AA6FF),
      onBrand: Color(0xFF0E1320),
      tokens: AppTokens(
        mutedText: Color(0xFF94A0B4),
        sunken: Color(0xFF161C2B),
        hairline: Color(0xFF232C3E),
        success: _successDark,
        warning: _warningDark,
        danger: _dangerDark,
        accent: Color(0xFFF29A5B),
        chartSeries: Color(0xFF8FA8FF),
        chartGrid: Color(0xFF222A3A),
        chartSales: Color(0xFF5B8DEF),
        chartCosts: Color(0xFFD98A3D),
      ),
    ),
  );

  static const lavenderCalm = ThemePreset(
    id: 'lavender_calm',
    name: 'Lavender Calm',
    blurb: 'Soft lilac with a deep violet — quiet and easy on the eyes.',
    light: ThemePalette(
      brightness: Brightness.light,
      ink: Color(0xFF1E1B2E),
      onInk: Color(0xFFFFFFFF),
      bg: Color(0xFFFFFFFF),
      mist: Color(0xFFE7E3F5),
      outline: Color(0xFFCCC6E0),
      brand: Color(0xFF5B45C2),
      onBrand: Color(0xFFFFFFFF),
      tokens: AppTokens(
        mutedText: Color(0xFF5F5977),
        sunken: Color(0xFFF5F3FB),
        hairline: Color(0xFFE9E6F3),
        success: _successLight,
        warning: _warningLight,
        danger: _dangerLight,
        accent: Color(0xFFB5541C),
        chartSeries: Color(0xFF6D5BD0),
        chartGrid: Color(0xFFE8E6F0),
        chartSales: Color(0xFF6552D0),
        chartCosts: Color(0xFFD4803A),
      ),
    ),
    dark: ThemePalette(
      brightness: Brightness.dark,
      ink: Color(0xFFECE9F7),
      onInk: Color(0xFF15131F),
      bg: Color(0xFF15131F),
      mist: Color(0xFF262236),
      outline: Color(0xFF3D3852),
      brand: Color(0xFFAE9FFF),
      onBrand: Color(0xFF15131F),
      tokens: AppTokens(
        mutedText: Color(0xFFA29CBC),
        sunken: Color(0xFF1D1A2A),
        hairline: Color(0xFF2A2639),
        success: _successDark,
        warning: _warningDark,
        danger: _dangerDark,
        accent: Color(0xFFF0A36B),
        chartSeries: Color(0xFFA393F5),
        chartGrid: Color(0xFF262233),
        chartSales: Color(0xFF8E7CF0),
        chartCosts: Color(0xFFD98B45),
      ),
    ),
  );

  static const editorialMono = ThemePreset(
    id: 'editorial_mono',
    name: 'Editorial Mono',
    blurb: 'Pure greyscale with one red for sales — high-contrast print look.',
    light: ThemePalette(
      brightness: Brightness.light,
      ink: Color(0xFF111111),
      onInk: Color(0xFFFFFFFF),
      bg: Color(0xFFFFFFFF),
      mist: Color(0xFFEDEDED),
      outline: Color(0xFFCFCFCF),
      brand: Color(0xFF111111),
      onBrand: Color(0xFFFFFFFF),
      tokens: AppTokens(
        mutedText: Color(0xFF5E5E5E),
        sunken: Color(0xFFF5F5F5),
        hairline: Color(0xFFE6E6E6),
        success: _successLight,
        warning: _warningLight,
        danger: _dangerLight,
        accent: Color(0xFFC8102E),
        chartSeries: Color(0xFF3A3A3A),
        chartGrid: Color(0xFFE8E8E8),
        chartSales: Color(0xFF3A3A3A),
        chartCosts: Color(0xFFD0413A),
      ),
    ),
    dark: ThemePalette(
      brightness: Brightness.dark,
      ink: Color(0xFFF0F0F0),
      onInk: Color(0xFF0F0F0F),
      bg: Color(0xFF0F0F0F),
      mist: Color(0xFF202020),
      outline: Color(0xFF3A3A3A),
      brand: Color(0xFFF0F0F0),
      onBrand: Color(0xFF0F0F0F),
      tokens: AppTokens(
        mutedText: Color(0xFFA3A3A3),
        sunken: Color(0xFF181818),
        hairline: Color(0xFF262626),
        success: _successDark,
        warning: _warningDark,
        danger: _dangerDark,
        accent: Color(0xFFFF6B6B),
        chartSeries: Color(0xFFC8C8C8),
        chartGrid: Color(0xFF262626),
        chartSales: Color(0xFFD6D6D6),
        chartCosts: Color(0xFFFF7A6B),
      ),
    ),
  );

  static const all = [studioSage, blushAtelier, terracottaSand, slateCobalt, lavenderCalm, editorialMono];

  /// Unknown or missing ids (e.g. a preset removed in a later version) fall
  /// back to the default rather than failing.
  static ThemePreset byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => studioSage);
}
