import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Floating snackbar with a leading status icon. It sits on the inverted
/// ink surface, where the theme's status colors lose contrast — so the icon
/// *shape* carries success vs. failure, and color stays on-ink.
void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  final onInk = context.colors.onPrimary;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, size: 18, color: onInk),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
