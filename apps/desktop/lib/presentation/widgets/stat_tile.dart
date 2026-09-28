import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// A figure on a card, as the Health and Fitness summaries set one: a
/// quiet label, the figure large beneath it, and an optional caption. No
/// border or shadow — stats are read, not clicked.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg + 2, 14, AppSpacing.lg + 2, 16),
      decoration: ShapeDecoration(
        color: context.colors.surface,
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.container)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: context.text.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// A row of equal-width stat tiles.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});
  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    // Equal heights even when only some tiles carry a caption.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}
