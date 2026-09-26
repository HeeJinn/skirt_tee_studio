import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';

import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/money_view_model.dart';
import '../../widgets/ui/section.dart';

/// Every entry the owners recorded — money put in, expenses, money taken
/// home — and every stock purchase, newest first, grouped by month.
class MoneyLogScreen extends StatelessWidget {
  const MoneyLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = context.watch<MoneyViewModel>().log;

    final byMonth = <DateTime, List<MoneyLogEntry>>{};
    for (final e in log) {
      byMonth.putIfAbsent(DateTime(e.at.year, e.at.month), () => []).add(e);
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Money log'), previousPageTitle: 'Money'),
      child: SafeArea(
        child: log.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text(
                  'Nothing recorded yet. Money put in, expenses, and stock bought show up here once recorded on the shop computer.',
                  style: ShopType.subhead(context),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: Space.xxl),
                children: [
                  for (final MapEntry(key: month, value: entries) in byMonth.entries)
                    GroupedSection(
                      title: DateFormat('MMMM y').format(month),
                      trailing: _net(entries),
                      children: [
                        for (final e in entries)
                          ValueRow(
                            label: e.title,
                            labelLines: 1,
                            detail: e.detail == null || e.detail!.isEmpty
                                ? DateFormat('MMM d').format(e.at)
                                : '${DateFormat('MMM d').format(e.at)} · ${e.detail}',
                            value: e.isMoneyIn ? '+${peso.format(e.amount)}' : minusPeso(e.amount),
                            tone: e.isMoneyIn ? ValueTone.positive : ValueTone.normal,
                          ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  /// The month's money in less money out, for the heading.
  static String _net(List<MoneyLogEntry> entries) {
    final net = entries.fold<double>(0, (sum, e) => sum + (e.isMoneyIn ? e.amount : -e.amount));
    return signedPeso(net, whole: true);
  }
}
