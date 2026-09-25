
import 'package:flutter/material.dart';

import 'theme_presets.dart';

export 'theme_presets.dart';

/// Brand primitives from "The Skirt & Tee Studio" logo (the Studio Sage
/// preset — the others live in theme_presets.dart): pale sage/mist,
/// black ink, minimalist editorial feel. Widgets should not reach for these
/// directly — they read semantic roles from [AppTokens] (via
/// `context.tokens`) or the [ColorScheme], which have hand-tuned light and
/// dark values. Every text-bearing token below was contrast-checked (WCAG)
/// against both surfaces and clears 4.5:1.
///
/// Shape language: radius 4 = interactive (buttons, chips, inputs, pills),
/// radius 10 = containers (cards, panels, dialogs). Two radii, two jobs.
class AppColors {
  AppColors._();

  // Light
  static const ink = Color(0xFF1A1A1A);
  static const mistSage = Color(0xFFDCE4DE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF3F5F3);
  static const outline = Color(0xFFC4CCC7);
  static const outlineFaint = Color(0xFFE3E8E4);

  // Dark — hand-tuned, not an inversion of the light values.
  static const darkBg = Color(0xFF15181A);
  static const darkSurface = Color(0xFF1D2023);
  static const darkMist = Color(0xFF262E2B);
  static const darkInk = Color(0xFFEDEFEC);
  static const darkOutline = Color(0xFF3A423E);
  static const darkOutlineFaint = Color(0xFF2A3330);
}

/// Semantic color roles. Status colors (success/warning/danger) carry fixed
/// meaning and always ship with a label, never color alone. `accent` (clay)
/// is reserved for the Bargain/SALE marker.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.mutedText,
    required this.sunken,
    required this.hairline,
    required this.success,
    required this.warning,
    required this.danger,
    required this.accent,
    required this.chartSeries,
    required this.chartGrid,
    required this.chartSales,
    required this.chartCosts,
  });

  /// Secondary text — never use `outline` (a border color) for text.
  final Color mutedText;
  final Color sunken;
  final Color hairline;
  final Color success;
  final Color warning;
  final Color danger;
  final Color accent;

  /// Single-series chart hue — a deep brand sage rather than a generic
  /// chart blue, so charts read as part of this app.
  final Color chartSeries;
  final Color chartGrid;

  /// The sales-vs-costs pair: a greener step of the brand sage and a clay.
  /// The single-series [chartSeries] is too muted to stand beside a second
  /// hue, so two-series charts use these instead. Checked with the dataviz
  /// palette validator (lightness band, chroma, CVD, contrast) against each
  /// mode's surface — re-run it if you change them.
  final Color chartSales;
  final Color chartCosts;

  static const light = AppTokens(
    mutedText: Color(0xFF5C6560),
    sunken: AppColors.surfaceSunken,
    hairline: AppColors.outlineFaint,
    success: Color(0xFF1B7A36),
    warning: Color(0xFF8A5A00),
    danger: Color(0xFFB3261E),
    accent: Color(0xFFA55A25),
    chartSeries: Color(0xFF3D6B5B),
    chartGrid: Color(0xFFE6E9E7),
    chartSales: Color(0xFF187C49),
    chartCosts: Color(0xFFD77E49),
  );

  static const dark = AppTokens(
    mutedText: Color(0xFF9BA59F),
    sunken: AppColors.darkSurface,
    hairline: AppColors.darkOutlineFaint,
    success: Color(0xFF6FD08F),
    warning: Color(0xFFE6B450),
    danger: Color(0xFFFF8A7F),
    accent: Color(0xFFE39A60),
    chartSeries: Color(0xFF7FB8A3),
    chartGrid: Color(0xFF262B2D),
    chartSales: Color(0xFF2EA37A),
    chartCosts: Color(0xFFC87A30),
  );

  @override
  AppTokens copyWith({
    Color? mutedText,
    Color? sunken,
    Color? hairline,
    Color? success,
    Color? warning,
    Color? danger,
    Color? accent,
    Color? chartSeries,
    Color? chartGrid,
    Color? chartSales,
    Color? chartCosts,
  }) {
    return AppTokens(
      mutedText: mutedText ?? this.mutedText,
      sunken: sunken ?? this.sunken,
      hairline: hairline ?? this.hairline,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      accent: accent ?? this.accent,
      chartSeries: chartSeries ?? this.chartSeries,
      chartGrid: chartGrid ?? this.chartGrid,
      chartSales: chartSales ?? this.chartSales,
      chartCosts: chartCosts ?? this.chartCosts,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      chartSeries: Color.lerp(chartSeries, other.chartSeries, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      chartSales: Color.lerp(chartSales, other.chartSales, t)!,
      chartCosts: Color.lerp(chartCosts, other.chartCosts, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  /// Falls back to the matching light/dark tokens under a theme that wasn't
  /// built by [AppTheme] (e.g. a bare MaterialApp), instead of crashing.
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.dark ? AppTokens.dark : AppTokens.light);
  }
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

class AppRadius {
  AppRadius._();
  static const control = 4.0;
  static const container = 10.0;
}

/// Serif for editorial display (screen and dialog titles) only. Everything
/// a user reads or acts on — including every number — is in the sans.
const kSerifFont = 'Georgia';

/// Declared explicitly rather than left to the OS fallback, so every
/// component style resolves the same face.
const kSansFont = 'Segoe UI';

/// Equal-width digits for numbers that align in columns (prices in lists,
/// quantities, totals in a row). Not for standalone hero figures.
const kTabularFigures = [FontFeature.tabularFigures()];

class AppTheme {
  AppTheme._();

  /// The default Studio Sage theme — kept as getters for callers (and tests)
  /// that don't care which preset is active.
  static ThemeData get light => fromPalette(ThemePresets.studioSage.light);
  static ThemeData get dark => fromPalette(ThemePresets.studioSage.dark);

  static ThemeData fromPalette(ThemePalette palette) => _build(
        brightness: palette.brightness,
        ink: palette.ink,
        onInk: palette.onInk,
        bg: palette.bg,
        mist: palette.mist,
        outline: palette.outline,
        brand: palette.brand,
        onBrand: palette.onBrand,
        tokens: palette.tokens,
      );

  /// [ink] is the neutral text/structure color; [brand] is the one saturated
  /// color reserved for primary actions and selection. Studio Sage sets them
  /// equal (its identity is black ink on sage); the other presets don't.
  static ThemeData _build({
    required Brightness brightness,
    required Color ink,
    required Color onInk,
    required Color bg,
    required Color mist,
    required Color outline,
    required Color brand,
    required Color onBrand,
    required AppTokens tokens,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: brand,
      onPrimary: onBrand,
      primaryContainer: mist,
      onPrimaryContainer: ink,
      secondary: tokens.accent,
      onSecondary: onInk,
      secondaryContainer: mist,
      onSecondaryContainer: ink,
      tertiary: tokens.chartSeries,
      onTertiary: onInk,
      surface: bg,
      onSurface: ink,
      onSurfaceVariant: tokens.mutedText,
      surfaceContainerHighest: tokens.sunken,
      surfaceContainerHigh: tokens.sunken,
      surfaceContainer: tokens.sunken,
      surfaceContainerLow: bg,
      surfaceContainerLowest: bg,
      outline: outline,
      outlineVariant: tokens.hairline,
      error: tokens.danger,
      onError: onInk,
      errorContainer: tokens.danger.withValues(alpha: 0.12),
      onErrorContainer: tokens.danger,
      shadow: Colors.black,
      inverseSurface: ink,
      onInverseSurface: bg,
      inversePrimary: mist,
    );

    TextStyle sans(double size, FontWeight weight, {double spacing = 0, Color? color, double? height}) =>
        TextStyle(
          fontFamily: kSansFont,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: color ?? ink,
          height: height,
        );

    TextStyle serif(double size, {double spacing = 0}) => TextStyle(
          fontFamily: kSerifFont,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: spacing,
          color: ink,
        );

    final textTheme = TextTheme(
      // Hero figures (POS total) and stat values — sans, proportional
      // figures, tight tracking. Never serif: Georgia has old-style
      // numerals and no ₱ glyph.
      displayMedium: sans(40, FontWeight.w600, spacing: -0.8, height: 1.1),
      displaySmall: sans(32, FontWeight.w600, spacing: -0.6, height: 1.1),
      headlineLarge: serif(26, spacing: 3),
      headlineMedium: sans(24, FontWeight.w600, spacing: -0.3, height: 1.15),
      // Screen titles.
      headlineSmall: serif(22, spacing: 4),
      // Dialog titles.
      titleLarge: serif(18, spacing: 1.5),
      titleMedium: sans(15, FontWeight.w600),
      // Section / card labels ("REVENUE TREND", "CURRENT SALE").
      titleSmall: sans(12, FontWeight.w700, spacing: 1.4),
      bodyLarge: sans(15, FontWeight.w400),
      bodyMedium: sans(14, FontWeight.w400),
      bodySmall: sans(12.5, FontWeight.w400, color: tokens.mutedText),
      labelLarge: sans(13, FontWeight.w600, spacing: 0.8),
      labelMedium: sans(12, FontWeight.w600, spacing: 0.4),
      // Stat labels, table headers — caps, muted.
      labelSmall: sans(11, FontWeight.w600, spacing: 1.0, color: tokens.mutedText),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );

    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control));
    final containerShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.container));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: kSansFont,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      extensions: [tokens],
      splashFactory: InkSparkle.splashFactory,
      hoverColor: ink.withValues(alpha: 0.04),
      visualDensity: VisualDensity.standard,

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: mist,
        indicatorColor: brand.withValues(alpha: 0.12),
        indicatorShape: controlShape,
        selectedIconTheme: IconThemeData(color: brand, size: 22),
        unselectedIconTheme: IconThemeData(color: tokens.mutedText, size: 22),
        selectedLabelTextStyle: sans(14, FontWeight.w600),
        unselectedLabelTextStyle: sans(14, FontWeight.w400, color: tokens.mutedText),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        titleTextStyle: textTheme.headlineSmall,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return tokens.hairline;
            if (states.contains(WidgetState.pressed)) return brand.withValues(alpha: 0.82);
            if (states.contains(WidgetState.hovered)) return brand.withValues(alpha: 0.9);
            return brand;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? tokens.mutedText : onBrand,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          elevation: const WidgetStatePropertyAll(0),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: outline),
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.mutedText,
          hoverColor: ink.withValues(alpha: 0.06),
          shape: controlShape,
        ),
      ),

      iconTheme: IconThemeData(color: ink, size: 20),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(AppRadius.control)),
        textStyle: sans(12, FontWeight.w500, color: onInk),
        waitDuration: const Duration(milliseconds: 400),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.container),
          side: BorderSide(color: tokens.hairline),
        ),
        textStyle: textTheme.bodyMedium,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.sunken,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: sans(14, FontWeight.w400, color: tokens.mutedText),
        floatingLabelStyle: sans(14, FontWeight.w600),
        hintStyle: sans(14, FontWeight.w400, color: tokens.mutedText),
        prefixIconColor: tokens.mutedText,
        border: inputBorder(outline),
        enabledBorder: inputBorder(tokens.hairline),
        focusedBorder: inputBorder(brand, 1.5),
        errorBorder: inputBorder(tokens.danger),
        focusedErrorBorder: inputBorder(tokens.danger, 1.5),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: BorderSide(color: outline, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(onBrand),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: bg,
        selectedColor: brand,
        disabledColor: tokens.hairline,
        labelStyle: sans(13, FontWeight.w500),
        secondaryLabelStyle: sans(13, FontWeight.w600, color: onBrand),
        side: BorderSide(color: tokens.hairline),
        shape: controlShape,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        showCheckmark: false,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: tokens.mutedText,
        textColor: ink,
        titleTextStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: EdgeInsets.zero,
        shape: controlShape,
      ),

      dividerTheme: DividerThemeData(color: tokens.hairline, thickness: 1, space: 1),

      cardTheme: CardThemeData(
        color: bg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.container),
          side: BorderSide(color: tokens.hairline),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        shape: containerShape,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: brand,
        headerForegroundColor: onBrand,
        shape: containerShape,
        todayBorder: BorderSide(color: brand),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: sans(14, FontWeight.w600, color: onInk),
        behavior: SnackBarBehavior.floating,
        width: 420,
        shape: controlShape,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(ink.withValues(alpha: 0.2)),
      ),
    );
  }
}
