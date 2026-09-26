import 'package:flutter/cupertino.dart';

import '../../../core/theme/shop_ui.dart';

/// On a solid status color: white in light mode; in dark mode the status
/// colors are pale, so the page's dark tone reads instead.
Color onStatus(BuildContext context) {
  final colors = ShopColors.of(context);
  return colors.isDark ? colors.page : const Color(0xFFFFFFFF);
}

/// An iOS Settings-style icon: a glyph on a small tinted square.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.badge)),
        child: Icon(icon, size: 18, color: onStatus(context)),
      );
}

/// A small rounded label on a tint of its own color: stock status on a
/// photo, a change against last week.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.color, this.icon, this.solid = false});

  final String text;
  final Color color;
  final IconData? icon;

  /// Solid fill with white text (for sitting on photos), rather than a tint.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? onStatus(context) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: ShopColors.of(context).isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
          Text(
            text,
            style: ShopType.caption(context).copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontFeatures: ShopType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// A change against a comparison, as a pill: "▲ 50%" in green, "▼ 12%" in
/// red, or a quiet dash when there's nothing to compare with.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.change});

  /// A fraction (0.5 = +50%), or null.
  final double? change;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final c = change;
    if (c == null) return Pill(text: 'New', color: colors.secondaryInk);
    if (c.abs() < 0.005) return Pill(text: 'Same', color: colors.secondaryInk);
    final up = c > 0;
    return Pill(
      text: '${(c.abs() * 100).round()}%',
      icon: up ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down_right,
      color: up ? colors.success : colors.danger,
    );
  }
}
