import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// A blocking question, laid out as an iOS 26 alert: a short centered
/// title, one or two centered sentences, and the choices side by side as
/// capsules — Cancel in grey on the leading side, the action on the
/// trailing side (red when it destroys something). Takes the same
/// arguments as [AlertDialog], so a confirmation switches over by name.
class IosAlert extends StatelessWidget {
  const IosAlert({super.key, required this.title, this.content, required this.actions});

  final Widget title;
  final Widget? content;

  /// Usually a Cancel [TextButton] and one [ElevatedButton].
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = context.tokens.sunken;
    // Inside the alert every choice is a full capsule: plain buttons turn
    // into grey ones, and all of them share one height.
    final alertTheme = theme.copyWith(
      textButtonTheme: TextButtonThemeData(
        style: theme.textButtonTheme.style?.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? fill.withValues(alpha: fill.a * 1.8) : fill,
          ),
          foregroundColor: WidgetStatePropertyAll(context.colors.onSurface),
          textStyle: WidgetStatePropertyAll(context.text.labelLarge),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: theme.elevatedButtonTheme.style?.copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 44))),
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DefaultTextStyle(
                style: context.text.titleMedium!,
                textAlign: TextAlign.center,
                child: Semantics(header: true, child: title),
              ),
              if (content != null) ...[
                const SizedBox(height: AppSpacing.sm),
                DefaultTextStyle(
                  style: context.text.bodyMedium!.copyWith(color: context.tokens.mutedText),
                  textAlign: TextAlign.center,
                  child: content!,
                ),
              ],
              const SizedBox(height: AppSpacing.lg + 4),
              Theme(
                data: alertTheme,
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
