import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

enum PillTone { neutral, success, warning, danger, accent }

/// Small status capsule on a tint of its own color, in sentence case.
/// Tone color is always paired with a text label, so meaning never rides
/// on color alone.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      PillTone.neutral => tokens.mutedText,
      PillTone.success => tokens.success,
      PillTone.warning => tokens.warning,
      PillTone.danger => tokens.danger,
      PillTone.accent => tokens.accent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.12),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kSansFont,
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          fontFeatures: kTabularFigures,
        ),
      ),
    );
  }
}
