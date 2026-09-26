import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/shop_ui.dart';

/// One destination in [ShopTabBar].
class ShopTab {
  const ShopTab({required this.label, required this.icon, required this.activeIcon});

  final String label;

  /// Outline, for tabs that aren't selected.
  final IconData icon;

  /// Filled, for the selected tab.
  final IconData activeIcon;
}

/// A floating glass tab bar in the style of iOS 26: a frosted capsule over
/// the content (light glass in light mode, dark glass in dark mode), every
/// tab an icon with its label beneath, and a soft glass platter that springs
/// across to the selected tab.
class ShopTabBar extends StatelessWidget {
  const ShopTabBar({super.key, required this.tabs, required this.currentIndex, required this.onTap});

  final List<ShopTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// The capsule's height; screens keep this much clear at the bottom.
  static const height = 64.0;

  /// Gap between the capsule and the bottom safe area.
  static const bottomGap = Space.xs;

  /// A gentle overshoot, like the system bar's selection.
  static const _spring = Cubic(0.34, 1.3, 0.5, 1);

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final dark = colors.isDark;

    // The glass: the page's own tone, mostly see-through, over a blur of
    // whatever scrolls underneath.
    final tint = dark ? const Color(0xFF232A28).withValues(alpha: 0.72) : const Color(0xFFFFFFFF).withValues(alpha: 0.72);
    final edge = dark ? const Color(0xFFFFFFFF).withValues(alpha: 0.10) : const Color(0xFFFFFFFF).withValues(alpha: 0.9);
    final platter = dark ? const Color(0xFFFFFFFF).withValues(alpha: 0.12) : colors.ink.withValues(alpha: 0.07);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: dark ? 0.3 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: height,
            padding: const EdgeInsets.all(Space.xs),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(Radii.pill),
              // The bright rim that makes it read as glass.
              border: Border.all(color: edge, width: 0.8),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / tabs.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 420),
                      curve: _spring,
                      left: slot * currentIndex,
                      top: 0,
                      bottom: 0,
                      width: slot,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: platter, borderRadius: BorderRadius.circular(Radii.pill)),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _TabItem(tab: tabs[i], selected: i == currentIndex, onTap: () => onTap(i)),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});

  final ShopTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final color = selected ? colors.ink : colors.secondaryInk;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('tab-${tab.label}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(selected ? tab.activeIcon : tab.icon, key: ValueKey(selected), size: 23, color: color),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: ShopType.caption(context).copyWith(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
                color: color,
              ),
              child: Text(tab.label, maxLines: 1, overflow: TextOverflow.clip, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}
