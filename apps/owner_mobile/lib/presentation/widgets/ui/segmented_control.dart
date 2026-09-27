import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/shop_ui.dart';

/// A segmented control in iOS 26's shape: a capsule track with a capsule
/// thumb that springs across to the chosen segment.
class ShopSegmentedControl<T extends Object> extends StatelessWidget {
  const ShopSegmentedControl({super.key, required this.value, required this.segments, required this.onChanged});

  final T value;

  /// Each choice and its label, in order.
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  static const height = 36.0;
  static const _inset = 3.0;
  static const _spring = Cubic(0.34, 1.2, 0.5, 1);

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final keys = segments.keys.toList();
    final selected = keys.indexOf(value);
    final track = colors.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.09) : colors.ink.withValues(alpha: 0.06);
    final thumb = colors.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.16) : colors.card;

    return Container(
      height: height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(Radii.pill)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / keys.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: _spring,
                left: slot * selected,
                top: 0,
                bottom: 0,
                width: slot,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: thumb,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    boxShadow: [
                      if (!colors.isDark)
                        BoxShadow(
                          color: const Color(0xFF000000).withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, key) in keys.indexed)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        label: segments[key],
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == selected) return;
                            HapticFeedback.selectionClick();
                            onChanged(key);
                          },
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedDefaultTextStyle(
                                  duration: Motion.fast,
                                  style: ShopType.subhead(context).copyWith(
                                    fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                                    color: i == selected ? colors.ink : colors.secondaryInk,
                                  ),
                                  child: Text(segments[key]!, maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
