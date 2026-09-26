import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// One bordered container holding rows separated by hairlines — the dense,
/// scannable pattern for transactional lists (sales, reservations,
/// customers, inventory), instead of a stack of separate floating cards.
class ListSurface extends StatelessWidget {
  const ListSurface({super.key, required this.children, this.header});

  final List<Widget> children;

  /// Optional column-header row, rendered on the sunken tone above the rows.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.container),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Container(color: tokens.sunken, child: header),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0 || header != null) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Caps label above a group, with optional right-aligned context (e.g. a
/// day's total).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing, this.color});

  final String label;
  final String? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.lg, 2, AppSpacing.sm),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: color == null ? style : style?.copyWith(color: color)),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: style?.copyWith(letterSpacing: 0.2, fontFeatures: kTabularFigures)),
        ],
      ),
    );
  }
}

/// Centered empty-state message with an icon — shown instead of a bare
/// "No X" string so an empty screen still explains what goes there.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: context.tokens.mutedText),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: context.text.bodyMedium?.copyWith(color: context.tokens.mutedText)),
        ],
      ),
    );
  }
}
