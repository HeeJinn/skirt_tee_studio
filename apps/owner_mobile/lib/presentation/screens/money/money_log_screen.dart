import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/sales_grouping.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/money_entry.dart';

import '../../../core/period.dart';
import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/money_view_model.dart';
import '../../widgets/ui/badges.dart';
import '../../widgets/ui/empty_state.dart';
import '../../widgets/ui/glass.dart';
import '../../widgets/ui/line_art.dart';
import '../../widgets/ui/period_bar.dart';
import '../../widgets/ui/section.dart';

/// Every entry the owners recorded — money put in, expenses, money taken
/// home — and every stock purchase, newest first. Everything is grouped by
/// month; a chosen month is grouped by day.
class MoneyLogScreen extends StatefulWidget {
  const MoneyLogScreen({super.key});

  @override
  State<MoneyLogScreen> createState() => _MoneyLogScreenState();
}

class _MoneyLogScreenState extends State<MoneyLogScreen> {
  Period _period = const Period.all();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MoneyViewModel>();
    final log = vm.log;
    final now = vm.now;
    final shown = log.where((e) => _period.contains(e.at)).toList();
    final byMonth = _period.kind == PeriodKind.all;
    final groups = groupByDate(shown, (e) => e.at, byMonth: byMonth);
    final moneyIn = shown.where((e) => e.isMoneyIn).fold<double>(0, (sum, e) => sum + e.amount);
    final moneyOut = shown.where((e) => !e.isMoneyIn).fold<double>(0, (sum, e) => sum + e.amount);

    return CupertinoPageScaffold(
      navigationBar: shopNavBar(title: 'Money log', backTo: 'Money'),
      child: SafeArea(
        child: log.isEmpty
            ? const EmptyState(
                drawing: LineArtDrawing.paper,
                message: 'Nothing recorded yet. Money put in, expenses, and stock bought show up here once recorded on the shop computer.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                    child: PeriodBar(
                      period: _period,
                      now: now,
                      earliest: log.last.at,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xs, Space.md, Space.gutter + Space.xs, 0),
                    child: Text(
                      shown.isEmpty
                          ? 'Nothing recorded ${_period.phrase(now)}.'
                          : [
                              if (moneyIn > 0) '${pesoWhole.format(moneyIn)} in',
                              if (moneyOut > 0) '${pesoWhole.format(moneyOut)} out',
                              '${shown.length} ${shown.length == 1 ? 'entry' : 'entries'}',
                            ].join(' · '),
                      style: ShopType.footnote(context),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: Space.xxl),
                      children: [
                        for (final (at, entries) in groups)
                          GroupedSection(
                            title: switch (_period.kind) {
                              PeriodKind.all => DateFormat('MMMM y').format(at),
                              PeriodKind.month => dayLabel(at, now),
                              // The stepper already names the day.
                              PeriodKind.day => null,
                            },
                            trailing: _period.kind == PeriodKind.day ? null : _net(entries),
                            gap: Space.lg,
                            children: [
                              for (final e in entries)
                                ValueRow(
                                  leading: _Badge(entry: e),
                                  label: e.title,
                                  labelLines: 1,
                                  detail: _detail(e, withDate: byMonth),
                                  value: e.isMoneyIn ? '+${peso.format(e.amount)}' : minusPeso(e.amount),
                                  tone: e.isMoneyIn ? ValueTone.positive : ValueTone.normal,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// The entry's note, led by its date when the group is a whole month.
  static String? _detail(MoneyLogEntry e, {required bool withDate}) {
    final note = e.detail == null || e.detail!.isEmpty ? null : e.detail;
    if (!withDate) return note;
    final date = DateFormat('MMM d').format(e.at);
    return note == null ? date : '$date · $note';
  }

  /// The group's money in less money out, for the heading.
  static String _net(List<MoneyLogEntry> entries) {
    final net = entries.fold<double>(0, (sum, e) => sum + (e.isMoneyIn ? e.amount : -e.amount));
    return signedPeso(net, whole: true);
  }
}

/// What an entry was, at a glance: money coming in, each kind of expense,
/// money taken home, stock bought.
class _Badge extends StatelessWidget {
  const _Badge({required this.entry});
  final MoneyLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final expense = colors.tokens.chartCosts;
    final (icon, color) = switch (entry.kind) {
      null => (CupertinoIcons.tag_fill, colors.accent),
      MoneyEntryKind.capitalIn => (CupertinoIcons.arrow_down, colors.success),
      MoneyEntryKind.ownerDraw => (CupertinoIcons.arrow_up_right, colors.warning),
      MoneyEntryKind.expense => (
          switch (entry.category) {
            ExpenseCategory.rent => CupertinoIcons.house_fill,
            ExpenseCategory.utilities => CupertinoIcons.bolt_fill,
            ExpenseCategory.wages => CupertinoIcons.person_2_fill,
            ExpenseCategory.marketing => CupertinoIcons.speaker_2_fill,
            ExpenseCategory.packaging => CupertinoIcons.cube_box_fill,
            ExpenseCategory.delivery => CupertinoIcons.car_fill,
            ExpenseCategory.supplies => CupertinoIcons.cart_fill,
            ExpenseCategory.repairs => CupertinoIcons.wrench_fill,
            ExpenseCategory.fees => CupertinoIcons.creditcard_fill,
            ExpenseCategory.other || null => CupertinoIcons.ellipsis,
          },
          expense,
        ),
    };
    return IconBadge(icon: icon, color: color);
  }
}
