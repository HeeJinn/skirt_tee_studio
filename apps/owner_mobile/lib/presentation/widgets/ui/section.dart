import 'package:flutter/cupertino.dart';

import '../../../core/theme/shop_ui.dart';

/// A section heading: sentence case, with an optional figure or note on the
/// right (a day's total, a period).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.top = Space.xl});

  final String title;
  final String? trailing;

  /// Space above: generous between sections.
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Space.gutter + Space.xs, top, Space.gutter + Space.xs, Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(title, style: ShopType.section(context))),
            if (trailing != null)
              Text(trailing!, style: ShopType.subhead(context).copyWith(fontFeatures: ShopType.tabular)),
          ],
        ),
      );
}

/// The space at the end of a scrolling screen: the bottom safe area (which
/// includes the floating tab bar) plus a little air, so the last row scrolls
/// clear of the bar.
class BottomInset extends StatelessWidget {
  const BottomInset({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: MediaQuery.paddingOf(context).bottom + Space.lg);
}

/// A small grey note under a section, as in iOS Settings.
class SectionFooter extends StatelessWidget {
  const SectionFooter(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter + Space.lg, Space.sm, Space.gutter + Space.lg, 0),
        child: Text(text, style: ShopType.footnote(context)),
      );
}

/// A heading, an iOS inset group of rows in the shop's card color, and an
/// optional footnote — the one way sections are drawn in the app.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.title,
    this.trailing,
    this.footer,
    this.gap = Space.xl,
    required this.children,
  });

  final String? title;
  final String? trailing;
  final String? footer;

  /// Space above a section without a heading (smaller when it belongs to a
  /// control just above it).
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) SectionHeader(title!, trailing: trailing) else SizedBox(height: gap),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(Radii.group)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.lg),
                    child: Container(height: 0.5, color: colors.hairline),
                  ),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null) SectionFooter(footer!),
      ],
    );
  }
}

/// How a row's figure is set.
enum ValueTone { normal, strong, muted, positive, negative }

/// One line of a grouped section: a label (and optional detail) on the
/// left, a figure on the right in full ink with tabular digits. Tappable
/// rows get a chevron and a pressed state.
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.label,
    this.detail,
    this.value,
    this.tone = ValueTone.normal,
    this.leading,
    this.indent = false,
    this.destructive = false,
    this.labelLines = 2,
    this.onTap,
  });

  final String label;
  final String? detail;
  final String? value;
  final ValueTone tone;
  final Widget? leading;

  /// A sub-line of the row above (an expense under gross profit).
  final bool indent;

  /// A red label, for actions like signing out.
  final bool destructive;
  final int labelLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final strong = tone == ValueTone.strong || tone == ValueTone.positive || tone == ValueTone.negative;
    final labelStyle = ShopType.body(context).copyWith(
      fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      // A muted row with a figure ("Money log  6") keeps its label in ink,
      // as iOS lists do; only a placeholder row ("No sales yet") is grey.
      color: destructive
          ? colors.danger
          : indent || (tone == ValueTone.muted && value == null)
              ? colors.secondaryInk
              : colors.ink,
    );
    final valueStyle = ShopType.amount(context).copyWith(
      fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      color: switch (tone) {
        ValueTone.positive => colors.success,
        ValueTone.negative => colors.danger,
        ValueTone.muted => colors.secondaryInk,
        _ => colors.ink,
      },
    );

    final row = Padding(
      padding: EdgeInsets.fromLTRB(indent ? Space.xl + Space.xs : Space.lg, 11, Space.lg, 11),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Space.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle, maxLines: labelLines, overflow: TextOverflow.ellipsis),
                if (detail != null) ...[
                  const SizedBox(height: Space.xxs),
                  Text(detail!, style: ShopType.footnote(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: Space.md),
            Text(value!, style: valueStyle),
          ],
          // Actions (sign out) don't open a page, so no chevron.
          if (onTap != null && !destructive) ...[
            const SizedBox(width: Space.sm),
            Icon(CupertinoIcons.chevron_forward, size: 16, color: colors.tertiaryInk),
          ],
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap!, child: row);
  }
}

/// A pressed state for anything tappable: the surface dims slightly while
/// the finger is down, like iOS list rows.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.child, this.scale = false});

  final VoidCallback onTap;
  final Widget child;

  /// Cards also shrink a touch; rows only dim.
  final bool scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: widget.scale && _down ? 0.97 : 1,
        duration: Motion.fast,
        curve: Motion.curve,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.curve,
          foregroundDecoration: BoxDecoration(
            color: _down ? colors.ink.withValues(alpha: colors.isDark ? 0.08 : 0.05) : const Color(0x00000000),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
