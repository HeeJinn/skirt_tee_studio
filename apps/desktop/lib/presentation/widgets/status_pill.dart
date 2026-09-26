import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

enum PillTone { neutral, success, warning, danger, accent }

/// Small status label. Tone color is always paired with a text label, so
/// meaning never rides on color alone.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = switch (tone) {
      PillTone.neutral => tokens.mutedText,
      PillTone.success => tokens.success,
      PillTone.warning => tokens.warning,
      PillTone.danger => tokens.danger,
      PillTone.accent => tokens.accent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kSansFont,
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
