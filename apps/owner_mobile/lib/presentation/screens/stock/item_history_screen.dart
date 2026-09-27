import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/sales_grouping.dart';

import '../../../core/period.dart';
import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/stock_view_model.dart';
import '../../widgets/ui/badges.dart';
import '../../widgets/ui/glass.dart';
import '../../widgets/ui/period_bar.dart';
import '../../widgets/ui/section.dart';
import 'item_history.dart';

/// Every change to one item's stock, narrowed to a month or a day if
/// wanted, with what happened in that stretch totted up at the top.
class ItemHistoryScreen extends StatefulWidget {
  const ItemHistoryScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemHistoryScreen> createState() => _ItemHistoryScreenState();
}

class _ItemHistoryScreenState extends State<ItemHistoryScreen> {
  Period _period = const Period.all();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockViewModel>();
    final item = vm.byId(widget.itemId);
    final now = vm.now;
    final history = item == null ? const <ItemHistoryEntry>[] : vm.historyOf(item.id);
    final shown = history.where((e) => _period.contains(e.at)).toList();
    final byMonth = _period.kind == PeriodKind.all;
    final groups = groupByDate(shown, (e) => e.at, byMonth: byMonth);

    return CupertinoPageScaffold(
      navigationBar: shopNavBar(title: 'History', backTo: item?.name ?? 'Item'),
      child: SafeArea(
        child: item == null
            ? Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text('This item was removed on the shop computer.', style: ShopType.subhead(context)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                    child: PeriodBar(
                      period: _period,
                      now: now,
                      earliest: history.isEmpty ? null : history.last.at,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xs, Space.md, Space.gutter + Space.xs, 0),
                    child: Text(
                      historySummary(shown) ?? 'No changes ${_period.phrase(now)}.',
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
                                ItemHistoryRow(
                                  entry: e,
                                  when: DateFormat(byMonth ? 'MMM d · h:mm a' : 'h:mm a').format(e.at),
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

  /// The group's pieces in less pieces out, for the heading.
  static String _net(List<ItemHistoryEntry> entries) {
    final net = entries.fold<int>(0, (sum, e) => sum + e.change);
    return net > 0 ? '+$net' : net < 0 ? '−${-net}' : '0';
  }
}

/// One change to an item's stock: what happened, when, and the pieces in
/// or out.
class ItemHistoryRow extends StatelessWidget {
  const ItemHistoryRow({super.key, required this.entry, required this.when});

  final ItemHistoryEntry entry;

  /// The date or time, as much as the surrounding group doesn't already say.
  final String when;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final e = entry;
    final (icon, color) = switch (e.kind) {
      ItemChangeKind.sold => (CupertinoIcons.bag_fill, colors.secondaryInk),
      ItemChangeKind.found => (CupertinoIcons.search, colors.accent),
      ItemChangeKind.received => (CupertinoIcons.cube_box_fill, colors.accent),
      ItemChangeKind.writtenOff => (CupertinoIcons.minus_circle_fill, colors.danger),
    };
    return ValueRow(
      leading: IconBadge(icon: icon, color: color),
      label: e.title,
      labelLines: 1,
      detail: e.detail == null ? when : '$when · ${e.detail}',
      value: e.change > 0 ? '+${e.change}' : '−${-e.change}',
      tone: e.change > 0 ? ValueTone.positive : ValueTone.strong,
    );
  }
}
