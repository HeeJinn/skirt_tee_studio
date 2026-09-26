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

/// A floating capsule of tabs: unselected tabs are outline icons; the
/// selected one opens into a light pill with a filled icon and its label.
/// The pill widens and the icon fills in as the selection moves.
class ShopTabBar extends StatelessWidget {
  const ShopTabBar({super.key, required this.tabs, required this.currentIndex, required this.onTap});

  final List<ShopTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// The capsule's height; screens keep this much clear at the bottom.
  static const height = 60.0;

  /// Gap between the capsule and the bottom safe area.
  static const bottomGap = Space.sm;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    // Light mode: the shop's ink as the capsule. Dark mode: one step above
    // the cards, with a hairline edge so it separates from the page.
    final barColor = colors.isDark ? colors.hero : colors.ink;

    return Container(
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: colors.isDark ? Border.all(color: colors.hairline) : null,
        // It genuinely floats over the content, so it earns a shadow.
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: colors.isDark ? 0.3 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < tabs.length; i++)
            i == currentIndex
                ? Flexible(child: _TabItem(tab: tabs[i], selected: true, onTap: () => onTap(i)))
                : _TabItem(tab: tabs[i], selected: false, onTap: () => onTap(i)),
        ],
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
    // The pill is the light tone of whichever mode: the card in light mode,
    // the ink (near-white) in dark mode.
    final pill = colors.isDark ? colors.ink : colors.card;
    final onPill = colors.isDark ? colors.page : colors.ink;
    final idle = (colors.isDark ? colors.ink : colors.card).withValues(alpha: 0.6);

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
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          height: double.infinity,
          constraints: const BoxConstraints(minWidth: 48),
          padding: EdgeInsets.symmetric(horizontal: selected ? Space.lg : Space.md),
          decoration: BoxDecoration(
            color: selected ? pill : pill.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  selected ? tab.activeIcon : tab.icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? onPill : idle,
                ),
              ),
              // The label only shows on the selected tab, sliding open; it
              // may shrink (and fade out at the edge) on a narrow phone.
              Flexible(
                child: AnimatedSize(
                  duration: Motion.medium,
                  curve: Motion.curve,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: Space.sm),
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: ShopType.body(context).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: onPill,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
