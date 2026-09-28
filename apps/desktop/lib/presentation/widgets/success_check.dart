import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// Animated check (plays once). Recolored from the theme at runtime, so the
/// one JSON asset works in light and dark mode; falls back to a static icon
/// when the OS asks for reduced motion.
class SuccessCheck extends StatelessWidget {
  const SuccessCheck({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.success;
    if (MediaQuery.of(context).disableAnimations) {
      return Icon(CupertinoIcons.checkmark_circle, size: size, color: color);
    }
    return Lottie.asset(
      'assets/lottie/success.json',
      width: size,
      height: size,
      repeat: false,
      delegates: LottieDelegates(values: [ValueDelegate.strokeColor(const ['**'], value: color)]),
    );
  }
}
