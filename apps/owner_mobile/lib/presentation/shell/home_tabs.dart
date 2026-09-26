import 'package:flutter/cupertino.dart';

import '../screens/more/more_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/today/today_screen.dart';
import '../widgets/tab_placeholder.dart';

/// The five tabs. Each keeps its own navigation stack, so switching tabs
/// and back returns to wherever you were.
class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  static const _tabs = [
    (CupertinoIcons.sun_max, 'Today'),
    (CupertinoIcons.doc_text, 'Sales'),
    (CupertinoIcons.tag, 'Stock'),
    (CupertinoIcons.money_dollar_circle, 'Money'),
    (CupertinoIcons.ellipsis_circle, 'More'),
  ];

  static Widget _page(int index) => switch (index) {
        0 => const TodayScreen(),
        1 => const SalesScreen(),
        2 => const TabPlaceholder(
            title: 'Stock',
            icon: CupertinoIcons.tag,
            message: 'Your items, with photos and what\'s running low, will show here.',
          ),
        3 => const TabPlaceholder(
            title: 'Money',
            icon: CupertinoIcons.money_dollar_circle,
            message: 'Payback, profit, and the money log will show here.',
          ),
        _ => const MoreScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          for (final (icon, label) in _tabs) BottomNavigationBarItem(icon: Icon(icon), label: label),
        ],
      ),
      tabBuilder: (_, index) => CupertinoTabView(builder: (_) => _page(index)),
    );
  }
}
