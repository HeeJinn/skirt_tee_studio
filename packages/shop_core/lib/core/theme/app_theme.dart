import 'package:flutter/cupertino.dart'
    show CupertinoPageTransitionsBuilder, CupertinoTextThemeData, CupertinoThemeData;
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
/// The shop computer's own theme ([AppTheme]) now draws its surfaces in
/// Apple's system colors ([SystemColors]) and keeps a preset's brand as the
/// accent; the phone app builds its theme from these palettes directly.
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
/// is reserved for the SALE marker.
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
    return theme.extension<AppTokens>() ?? (theme.brightness == Brightness.dark ? AppTokens.dark : AppTokens.light);
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

/// The shop computer's shapes, as iPadOS 26 rounds them: controls are
/// capsules; cards, list groups, and sheets share generous radii, and
/// anything set inside a card takes that radius less its padding.
class AppRadius {
  AppRadius._();

  /// Small rounded things that aren't capsules: thumbnails, text fields.
  static const control = 12.0;

  /// Cards, list groups, panels.
  static const container = 22.0;

  /// Dialogs and sheets.
  static const sheet = 28.0;
  static const pill = 999.0;
}

/// Kept for callers that still name it; titles are in the sans now, as on
/// iOS, where the system font sets everything.
const kSerifFont = kSansFont;

/// Inter, the closest free match to Apple's San Francisco (which can't be
/// shipped on Windows). Bundled with the desktop app.
const kSansFont = 'Inter';

/// Equal-width digits for numbers that align in columns (prices in lists,
/// quantities, totals in a row). Not for standalone hero figures.
const kTabularFigures = [FontFeature.tabularFigures()];

/// Apple's system colors for one brightness: grouped page, card, labels,
/// separators and fills, and the status colors (in their accessible shades
/// in light mode, so they hold up as text on white).
class SystemColors {
  const SystemColors._({
    required this.page,
    required this.surface,
    required this.elevated,
    required this.label,
    required this.secondaryLabel,
    required this.separator,
    required this.opaqueSeparator,
    required this.fill,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static const light = SystemColors._(
    page: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    label: Color(0xFF000000),
    // secondaryLabel, made opaque and a shade deeper so small text on the
    // page still clears 4.5:1.
    secondaryLabel: Color(0xFF6C6C70),
    separator: Color(0xFFD1D1D6),
    opaqueSeparator: Color(0xFFC6C6C8),
    fill: Color(0x1F767680),
    success: Color(0xFF248A3D),
    warning: Color(0xFFC93400),
    danger: Color(0xFFD70015),
  );

  static const dark = SystemColors._(
    page: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    elevated: Color(0xFF2C2C2E),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xFF98989F),
    separator: Color(0xFF38383A),
    opaqueSeparator: Color(0xFF48484A),
    fill: Color(0x3D767680),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
    danger: Color(0xFFFF453A),
  );

  static SystemColors of(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  /// Grouped page background.
  final Color page;

  /// Cards and list groups on the page.
  final Color surface;

  /// Dialogs, menus, and popovers above the page.
  final Color elevated;
  final Color label;
  final Color secondaryLabel;
  final Color separator;
  final Color opaqueSeparator;

  /// Quiet control fill: text fields, unselected capsules, tracks.
  final Color fill;
  final Color success;
  final Color warning;
  final Color danger;
}

extension SystemColorsContext on BuildContext {
  /// Apple's system colors for the current brightness.
  SystemColors get system => SystemColors.of(Theme.of(this).brightness);
}

class AppTheme {
  AppTheme._();

  /// The default Studio Sage theme — kept as getters for callers (and tests)
  /// that don't care which preset is active.
  static ThemeData get light => fromPalette(ThemePresets.studioSage.light);
  static ThemeData get dark => fromPalette(ThemePresets.studioSage.dark);

  /// The shop computer's theme, laid out the way iPadOS 26 draws an app:
  /// Apple's grouped grays and labels for every surface, and the chosen
  /// preset's brand color as the one accent (primary buttons, selection,
  /// links, focus). The preset's chart and SALE colors carry over as they
  /// are.
  static ThemeData fromPalette(ThemePalette palette) {
    final sys = SystemColors.of(palette.brightness);
    final dark = palette.brightness == Brightness.dark;
    final brand = palette.brand;
    final onBrand = palette.onBrand;
    final ink = sys.label;
    final muted = sys.secondaryLabel;
    // A soft wash of the accent for monograms and placeholders.
    final wash = Color.alphaBlend(brand.withValues(alpha: dark ? 0.24 : 0.12), sys.surface);
    // Accent text on grey or the page: a near-black accent (Studio Sage's
    // ink) reads as label color in dark mode.
    final accentText = dark && brand.computeLuminance() < 0.2 ? ink : brand;
    final tokens = palette.tokens.copyWith(
      mutedText: muted,
      sunken: sys.fill,
      hairline: sys.separator,
      success: sys.success,
      warning: sys.warning,
      danger: sys.danger,
      chartGrid: sys.separator,
    );

    final colorScheme = ColorScheme(
      brightness: palette.brightness,
      primary: brand,
      onPrimary: onBrand,
      primaryContainer: wash,
      onPrimaryContainer: ink,
      secondary: tokens.accent,
      onSecondary: onBrand,
      secondaryContainer: wash,
      onSecondaryContainer: ink,
      tertiary: tokens.chartSeries,
      onTertiary: onBrand,
      surface: sys.surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerHighest: sys.elevated,
      surfaceContainerHigh: sys.elevated,
      surfaceContainer: sys.surface,
      surfaceContainerLow: sys.surface,
      surfaceContainerLowest: sys.surface,
      outline: sys.opaqueSeparator,
      outlineVariant: sys.separator,
      error: sys.danger,
      onError: const Color(0xFFFFFFFF),
      errorContainer: sys.danger.withValues(alpha: 0.12),
      onErrorContainer: sys.danger,
      shadow: Colors.black,
      inverseSurface: ink,
      onInverseSurface: sys.surface,
      inversePrimary: wash,
    );

    // Apple's Dynamic Type sizes at their default setting, with Inter's
    // tracking pulled in to match San Francisco's color on the page.
    TextStyle sans(double size, FontWeight weight, {Color? color, double? height}) => TextStyle(
      fontFamily: kSansFont,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: _tracking(size),
      color: color ?? ink,
      height: height,
    );

    final textTheme = TextTheme(
      // Hero figures (POS total).
      displayMedium: sans(40, FontWeight.w700, height: 1.1),
      // Large Title: big figures in cards.
      displaySmall: sans(34, FontWeight.w700, height: 1.1),
      // Title 1.
      headlineLarge: sans(28, FontWeight.w700, height: 1.15),
      // Title 2: stat figures.
      headlineMedium: sans(22, FontWeight.w700, height: 1.2),
      // Screen titles: the Large Title, left-aligned, sentence case.
      headlineSmall: sans(34, FontWeight.w700, height: 1.15),
      // Dialog and sheet titles: Title 3.
      titleLarge: sans(20, FontWeight.w700),
      // Headline: emphasized rows.
      titleMedium: sans(17, FontWeight.w600),
      // Card and section titles ("Current sale", "Revenue trend").
      titleSmall: sans(17, FontWeight.w600),
      bodyLarge: sans(17, FontWeight.w400),
      // Subheadline: the default for text in rows and tables.
      bodyMedium: sans(15, FontWeight.w400),
      // Footnote: secondary lines.
      bodySmall: sans(13, FontWeight.w400, color: muted),
      // Buttons.
      labelLarge: sans(15, FontWeight.w600),
      labelMedium: sans(13, FontWeight.w600),
      // Stat labels and column headers: Footnote, secondary, never caps.
      labelSmall: sans(13, FontWeight.w500, color: muted),
    );

    const capsule = StadiumBorder();
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control));
    final card = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.container));
    final sheet = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.sheet));

    OutlineInputBorder field([Color? color, double width = 2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: width),
    );

    // Pressed controls dim, as iOS controls do; no ripples anywhere.
    Color dim(Color base, Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) return base.withValues(alpha: base.a * 0.7);
      if (states.contains(WidgetState.hovered)) return base.withValues(alpha: base.a * 0.88);
      return base;
    }

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: colorScheme,
      fontFamily: kSansFont,
      scaffoldBackgroundColor: sys.page,
      canvasColor: sys.page,
      textTheme: textTheme,
      extensions: [tokens],
      splashFactory: NoSplash.splashFactory,
      highlightColor: ink.withValues(alpha: 0.06),
      hoverColor: ink.withValues(alpha: 0.04),
      focusColor: brand.withValues(alpha: 0.18),
      visualDensity: VisualDensity.standard,
      // Screens slide in from the side and swipe back, as on iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: brand,
        primaryContrastingColor: onBrand,
        textTheme: CupertinoTextThemeData(
          primaryColor: brand,
          textStyle: sans(17, FontWeight.w400),
          pickerTextStyle: sans(21, FontWeight.w400),
          dateTimePickerTextStyle: sans(21, FontWeight.w400),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: sys.page,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleMedium,
      ),

      // The one prominent action: an accent capsule.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? sys.fill : dim(brand, states),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : onBrand,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : onBrand,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          shape: const WidgetStatePropertyAll(capsule),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          elevation: const WidgetStatePropertyAll(0),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? sys.fill : dim(brand, states),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : onBrand,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
          shape: const WidgetStatePropertyAll(capsule),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),

      // Secondary actions: a grey capsule with the label in the accent, as
      // iOS draws a bordered button. No outlines.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? sys.fill.withValues(alpha: sys.fill.a * 0.6)
                : dim(sys.fill, states),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : accentText,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : accentText,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: const WidgetStatePropertyAll(BorderSide.none),
          minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
          shape: const WidgetStatePropertyAll(capsule),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),

      // Plain actions: accent text, no fill.
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return muted;
            return states.contains(WidgetState.pressed) ? accentText.withValues(alpha: 0.6) : accentText;
          }),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered) ? sys.fill : Colors.transparent,
          ),
          minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
          shape: const WidgetStatePropertyAll(capsule),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted.withValues(alpha: 0.5) : muted,
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return ink.withValues(alpha: 0.1);
            if (states.contains(WidgetState.hovered)) return sys.fill;
            return Colors.transparent;
          }),
          shape: const WidgetStatePropertyAll(CircleBorder()),
        ),
      ),

      iconTheme: IconThemeData(color: ink, size: 20),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: sys.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sys.separator, width: 0.5),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        textStyle: sans(12, FontWeight.w500),
        waitDuration: const Duration(milliseconds: 400),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: sys.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x55000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.bodyMedium,
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(sys.elevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
      ),

      // iOS text fields: a quiet filled rounded box with no outline, and an
      // accent ring while typing in it.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sys.fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        labelStyle: sans(15, FontWeight.w400, color: muted),
        floatingLabelStyle: sans(13, FontWeight.w500, color: muted),
        hintStyle: sans(15, FontWeight.w400, color: muted.withValues(alpha: 0.8)),
        helperStyle: textTheme.bodySmall,
        errorStyle: sans(13, FontWeight.w400, color: sys.danger),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: field(),
        enabledBorder: field(),
        disabledBorder: field(),
        focusedBorder: field(accentText),
        errorBorder: field(sys.danger, 1),
        focusedErrorBorder: field(sys.danger),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: sys.opaqueSeparator, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(onBrand),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? sys.success : sys.fill,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // Filter capsules: grey until chosen, then filled with the accent.
      chipTheme: ChipThemeData(
        backgroundColor: sys.fill,
        selectedColor: brand,
        disabledColor: sys.fill,
        labelStyle: sans(14, FontWeight.w500),
        secondaryLabelStyle: sans(14, FontWeight.w600, color: onBrand),
        side: BorderSide.none,
        shape: capsule,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        showCheckmark: false,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: ink,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: EdgeInsets.zero,
        shape: rounded,
      ),

      dividerTheme: DividerThemeData(color: sys.separator, thickness: 0.5, space: 1),

      cardTheme: CardThemeData(color: sys.surface, elevation: 0, margin: EdgeInsets.zero, shape: card),

      dialogTheme: DialogThemeData(
        backgroundColor: sys.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: dark ? 0.5 : 0.25),
        shape: sheet,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: sys.elevated,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: sys.elevated,
        headerForegroundColor: ink,
        shape: sheet,
        dayShape: const WidgetStatePropertyAll(CircleBorder()),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onBrand : accentText,
        ),
        todayBorder: BorderSide.none,
        cancelButtonStyle: TextButton.styleFrom(shape: capsule),
        confirmButtonStyle: TextButton.styleFrom(shape: capsule),
      ),

      // iOS has no toasts; the few confirmations that need one float as a
      // dark capsule, like the system's own HUD banners.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF3A3A3C) : const Color(0xFF1C1C1E),
        contentTextStyle: sans(15, FontWeight.w600, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        width: 420,
        elevation: 12,
        shape: capsule,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(ink.withValues(alpha: 0.25)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: brand, linearTrackColor: sys.fill),
    );
  }
}

/// Inter's letter spacing at a size, tightened to sit like San Francisco:
/// firmer at display sizes, a touch tight at text sizes.
double _tracking(double size) {
  if (size >= 28) return -size * 0.022;
  if (size >= 20) return -size * 0.017;
  if (size >= 17) return -0.3;
  if (size >= 15) return -0.2;
  if (size >= 13) return -0.05;
  return 0;
}
