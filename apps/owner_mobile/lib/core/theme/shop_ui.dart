import 'package:flutter/cupertino.dart';
import 'package:shop_core/core/theme/app_theme.dart';

import 'cupertino_theme.dart';

/// The owner app's design system on top of Cupertino: the shop's palette
/// resolved for light or dark, a type scale, spacing, and radii. Screens use
/// these instead of inventing sizes and colors inline.

/// 4pt spacing scale. Group related things tightly (xs–sm), separate
/// sections generously (lg–xl).
abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Left and right margin of every card and section, matching iOS inset
  /// grouped lists.
  static const gutter = 16.0;
}

/// Radii by role, not one global value: cards are soft, list groups follow
/// iOS, and small tokens (pills, badges) are tighter or fully round.
abstract final class Radii {
  static const card = 16.0;
  static const group = 12.0;
  static const photo = 12.0;
  static const badge = 7.0;
  static const pill = 999.0;
}

/// The shop's colors for the current light/dark mode. Dark is the palette's
/// own designed dark, not an inversion.
class ShopColors {
  const ShopColors._({
    required this.page,
    required this.card,
    required this.hero,
    required this.ink,
    required this.secondaryInk,
    required this.tertiaryInk,
    required this.hairline,
    required this.accent,
    required this.tokens,
    required this.isDark,
  });

  factory ShopColors.of(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final palette = dark ? kShopPreset.dark : kShopPreset.light;
    final tokens = palette.tokens;
    return ShopColors._(
      // Light: faintly sage page, white cards. Dark: deepest tone for the
      // page, one step up for cards.
      page: dark ? palette.bg : tokens.sunken,
      card: dark ? tokens.sunken : palette.bg,
      hero: palette.mist,
      ink: palette.ink,
      secondaryInk: tokens.mutedText,
      tertiaryInk: tokens.mutedText.withValues(alpha: 0.7),
      hairline: tokens.hairline,
      accent: tokens.chartSeries,
      tokens: tokens,
      isDark: dark,
    );
  }

  /// Behind everything.
  final Color page;

  /// Cards and list groups.
  final Color card;

  /// The one surface per screen that should draw the eye: the shop's mist.
  final Color hero;

  final Color ink;
  final Color secondaryInk;
  final Color tertiaryInk;
  final Color hairline;

  /// The shop's deep sage: progress, chart highlights, links.
  final Color accent;

  /// Status and chart colors: success, warning, danger, chart series.
  final AppTokens tokens;
  final bool isDark;

  Color get success => tokens.success;
  Color get warning => tokens.warning;
  Color get danger => tokens.danger;
}

/// The type scale. Large titles are set in Georgia, like the shop
/// computer's screen titles; everything else is the system font. Money is
/// always tabular so columns of figures line up.
abstract final class ShopType {
  static const serif = 'Georgia';
  static const tabular = [FontFeature.tabularFigures()];

  static TextStyle _base(BuildContext context) => CupertinoTheme.of(context).textTheme.textStyle;

  /// The one figure a screen is about (today's sales, a sale's total).
  static TextStyle hero(BuildContext context) => _base(context).copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
        fontFeatures: tabular,
        color: ShopColors.of(context).ink,
      );

  /// A figure in a stat row or card.
  static TextStyle stat(BuildContext context) => _base(context).copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.1,
        fontFeatures: tabular,
        color: ShopColors.of(context).ink,
      );

  /// Section headings: sentence case, never shouted.
  static TextStyle section(BuildContext context) => _base(context).copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ShopColors.of(context).ink,
      );

  static TextStyle body(BuildContext context) => _base(context).copyWith(
        fontSize: 17,
        letterSpacing: -0.4,
        color: ShopColors.of(context).ink,
      );

  /// Money in a list row: full ink (it's the content), tabular.
  static TextStyle amount(BuildContext context) => body(context).copyWith(fontFeatures: tabular);

  static TextStyle subhead(BuildContext context) => _base(context).copyWith(
        fontSize: 15,
        letterSpacing: -0.2,
        color: ShopColors.of(context).secondaryInk,
      );

  static TextStyle footnote(BuildContext context) => _base(context).copyWith(
        fontSize: 13,
        letterSpacing: -0.1,
        height: 1.3,
        color: ShopColors.of(context).secondaryInk,
      );

  /// Small labels over figures ("Gross profit", "Sales made").
  static TextStyle label(BuildContext context) => _base(context).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        color: ShopColors.of(context).secondaryInk,
      );

  static TextStyle caption(BuildContext context) => _base(context).copyWith(
        fontSize: 12,
        letterSpacing: 0,
        color: ShopColors.of(context).secondaryInk,
      );
}

/// How fast things respond: quick enough to feel direct.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}
