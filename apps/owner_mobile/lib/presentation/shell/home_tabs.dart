import 'package:flutter/cupertino.dart';

import '../../core/theme/shop_ui.dart';
import '../screens/money/money_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/stock/stock_screen.dart';
import '../screens/today/today_screen.dart';
import '../widgets/ui/shop_tab_bar.dart';

/// The five tabs under a floating tab bar. Each tab keeps its own
/// navigation stack, so switching tabs and back returns to wherever you
/// were; tapping the current tab again returns to its first screen, as on
/// iOS.
class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  static const tabs = [
    ShopTab(label: 'Today', icon: CupertinoIcons.sun_max, activeIcon: CupertinoIcons.sun_max_fill),
    ShopTab(label: 'Sales', icon: CupertinoIcons.doc_text, activeIcon: CupertinoIcons.doc_text_fill),
    ShopTab(label: 'Stock', icon: CupertinoIcons.tag, activeIcon: CupertinoIcons.tag_fill),
    ShopTab(
      label: 'Money',
      icon: CupertinoIcons.money_dollar_circle,
      activeIcon: CupertinoIcons.money_dollar_circle_fill,
    ),
    ShopTab(label: 'More', icon: CupertinoIcons.ellipsis_circle, activeIcon: CupertinoIcons.ellipsis_circle_fill),
  ];

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;
  final _navigators = List.generate(HomeTabs.tabs.length, (_) => GlobalKey<NavigatorState>());

  static Widget _page(int index) => switch (index) {
        0 => const TodayScreen(),
        1 => const SalesScreen(),
        2 => const StockScreen(),
        3 => const MoneyScreen(),
        _ => const MoreScreen(),
      };

  void _select(int index) {
    if (index == _index) {
      _navigators[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final page = ShopColors.of(context).page;
    // Screens keep the floating bar's height clear at the bottom, so their
    // last row scrolls up above it.
    final withBar = media.copyWith(
      padding: media.padding.copyWith(
        bottom: media.padding.bottom + ShopTabBar.height + ShopTabBar.bottomGap,
      ),
    );

    return Stack(
      children: [
        MediaQuery(
          data: withBar,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < HomeTabs.tabs.length; i++)
                // Hidden tabs keep their state but stop animating.
                TickerMode(
                  enabled: i == _index,
                  child: CupertinoTabView(navigatorKey: _navigators[i], builder: (_) => _page(i)),
                ),
            ],
          ),
        ),
        // Content fades into the page behind the bar, so rows scrolling
        // underneath don't collide with it.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: media.padding.bottom + ShopTabBar.bottomGap + ShopTabBar.height + Space.xl,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [page.withValues(alpha: 0), page.withValues(alpha: 0.9), page],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: Space.gutter,
          right: Space.gutter,
          bottom: media.padding.bottom + ShopTabBar.bottomGap,
          child: ShopTabBar(tabs: HomeTabs.tabs, currentIndex: _index, onTap: _select),
        ),
      ],
    );
  }
}
