import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// Every screen's header, as iPadOS titles a page: a left-aligned large
/// title in sentence case, a live one-line summary beneath it, and the
/// page's actions on the right as capsules. Fixed geometry so the title
/// sits in the same place on every screen as you move through the nav.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: context.text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.text.bodyMedium?.copyWith(color: context.tokens.mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            actions[i],
          ],
        ],
      ),
    );
  }
}
