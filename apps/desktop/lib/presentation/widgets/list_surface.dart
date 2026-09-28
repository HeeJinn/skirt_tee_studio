import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// An inset grouped list, as iOS draws one: rows on the card color in one
/// rounded group, separated by hairlines that start where the text does —
/// the dense, scannable pattern for transactional lists (sales,
/// reservations, customers, inventory), instead of a stack of separate
/// floating cards.
class ListSurface extends StatelessWidget {
  const ListSurface({super.key, required this.children, this.header, this.separatorIndent = AppSpacing.lg});

  final List<Widget> children;

  /// Optional column-header row, set quietly above the rows.
  final Widget? header;

  /// Where row separators start, so they clear a leading thumbnail.
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: context.colors.surface,
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.container)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            DefaultTextStyle.merge(style: context.text.labelSmall, child: header!),
            const Divider(),
          ],
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(indent: separatorIndent),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A heading above a group, in sentence case as iOS 26 sets them, with
/// optional right-aligned context (e.g. a day's total).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing, this.color});

  final String label;
  final String? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.text.titleSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Semantics(
            header: true,
            child: Text(label, style: color == null ? style : style?.copyWith(color: color)),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: context.text.bodyMedium?.copyWith(
                color: context.tokens.mutedText,
                fontFeatures: kTabularFigures,
              ),
            ),
        ],
      ),
    );
  }
}

/// What a screen shows when there's nothing in it, like iOS's
/// ContentUnavailableView: a large symbol, a short title, and a line on
/// what fills it.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.title});

  final IconData icon;
  final String message;

  /// Two to four words ("No Sales Yet"). Optional: without it the message
  /// stands alone.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.mutedText;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: muted.withValues(alpha: 0.7)),
            const SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Text(title!, textAlign: TextAlign.center, style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: muted)),
          ],
        ),
      ),
    );
  }
}
