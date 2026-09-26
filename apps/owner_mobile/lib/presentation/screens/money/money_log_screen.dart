import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';

import '../../../core/theme/cupertino_theme.dart';
import '../../viewmodels/money_view_model.dart';

/// Every entry the owners recorded — money put in, expenses, money taken
/// home — and every stock purchase, newest first, grouped by month.
class MoneyLogScreen extends StatelessWidget {
  const MoneyLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = context.watch<MoneyViewModel>().log;
    final tokens = shopTokens(context);

    final byMonth = <DateTime, List<MoneyLogEntry>>{};
    for (final e in log) {
      byMonth.putIfAbsent(DateTime(e.at.year, e.at.month), () => []).add(e);
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Money log'), previousPageTitle: 'Money'),
      child: SafeArea(
        child: log.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'Nothing recorded yet. Money put in, expenses, and stock bought show up here once recorded on the shop computer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final MapEntry(key: month, value: entries) in byMonth.entries)
                    CupertinoListSection.insetGrouped(
                      header: Text(DateFormat('MMMM y').format(month).toUpperCase()),
                      children: [
                        for (final e in entries)
                          CupertinoListTile(
                            title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              e.detail == null || e.detail!.isEmpty
                                  ? DateFormat('MMM d').format(e.at)
                                  : '${DateFormat('MMM d').format(e.at)} · ${e.detail}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            additionalInfo: Text(
                              e.isMoneyIn ? '+${peso.format(e.amount)}' : minusPeso(e.amount),
                              style: TextStyle(color: e.isMoneyIn ? tokens.success : null),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
