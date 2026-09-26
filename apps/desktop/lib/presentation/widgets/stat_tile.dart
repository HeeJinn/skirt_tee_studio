import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// Label + big sans figure (+ optional caption). Tonal surface, no border —
/// stats are read, not clicked, so they don't wear the interactive chrome.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 14, AppSpacing.lg, 14),
      decoration: BoxDecoration(
        color: context.tokens.sunken,
        borderRadius: BorderRadius.circular(AppRadius.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: context.text.labelSmall),
          const SizedBox(height: 6),
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
