import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/item.dart';

import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/stock_view_model.dart';
import '../../widgets/item_photo.dart';
import '../../widgets/ui/badges.dart';
import '../../widgets/ui/section.dart';
import 'item_history.dart';

/// One item: its photo, what it sells for and costs, how much is left and
/// how fast it's selling, and every change to its stock. Looked up by id, so
/// an item removed on the shop computer while open says so.
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  /// History rows shown before "and N more".
  static const historyLimit = 15;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockViewModel>();
    final item = vm.byId(itemId);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(item?.name ?? 'Item', maxLines: 1, overflow: TextOverflow.ellipsis),
        previousPageTitle: 'Stock',
      ),
      child: SafeArea(
        bottom: false,
        child: item == null
            ? Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text('This item was removed on the shop computer.', style: ShopType.subhead(context)),
              )
            : ListView(
                padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + Space.lg),
                children: [
                  if (item.imagePath != null)
                    // Full width, edge to edge: the photo is what identifies
                    // the piece at a glance.
                    AspectRatio(aspectRatio: 4 / 3, child: ItemPhoto(imagePath: item.imagePath, name: item.name)),
                  _Title(item: item),
                  _Figures(item: item),
                  _Details(item: item),
                  _History(entries: vm.historyOf(item.id)),
                ],
              ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final vm = context.read<StockViewModel>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xs, Space.lg, Space.gutter + Space.xs, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: ShopType.section(context).copyWith(fontFamily: ShopType.serif, fontSize: 26, letterSpacing: -0.4),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              Pill(text: item.category, color: colors.secondaryInk),
              if (item.isBargain) Pill(text: 'Bargain', color: colors.accent),
              if (vm.isSoldOut(item))
                Pill(text: 'Sold out', color: colors.danger)
              else if (vm.isLow(item))
                Pill(text: 'Low stock', color: colors.warning),
            ],
          ),
        ],
      ),
    );
  }
}

/// On hand, price, and what each piece makes, side by side.
class _Figures extends StatelessWidget {
  const _Figures({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final cost = item.unitCost;
    final margin = cost == null ? null : item.unitPrice - cost;
    final figures = [
      ('On hand', '${item.qtyOnHand > 0 ? item.qtyOnHand : 0}', null),
      ('Sells for', pesoWhole.format(item.unitPrice), null),
      (
        'Makes each',
        margin == null ? '—' : signedPeso(margin, whole: true),
        margin == null || item.unitPrice == 0 ? 'cost unknown' : '${(margin / item.unitPrice * 100).round()}% margin',
      ),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(Radii.card)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < figures.length; i++) ...[
              if (i > 0) Container(width: 0.5, color: colors.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(figures[i].$1, style: ShopType.label(context)),
                      const SizedBox(height: Space.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(figures[i].$2, style: ShopType.stat(context)),
                      ),
                      if (figures[i].$3 != null) ...[
                        const SizedBox(height: Space.xs),
                        Text(figures[i].$3!, style: ShopType.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<StockViewModel>();
    final cost = item.unitCost;
    final onHand = item.qtyOnHand > 0 ? item.qtyOnHand : 0;
    final sold = vm.soldInLast30Days(item.id);
    return GroupedSection(
      title: 'Details',
      footer: cost == null ? "No cost recorded yet, so what this item makes is unknown." : null,
      children: [
        ValueRow(label: 'Costs', value: cost == null ? 'Not recorded' : '${peso.format(cost)} each',
            tone: cost == null ? ValueTone.muted : ValueTone.normal),
        if (cost != null) ValueRow(label: 'Stock worth, at cost', value: peso.format(onHand * cost)),
        ValueRow(label: 'Sold, last 30 days', value: '$sold ${sold == 1 ? 'piece' : 'pieces'}'),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.entries});
  final List<ItemHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final shown = entries.take(ItemDetailScreen.historyLimit).toList();
    final hidden = entries.length - shown.length;

    (IconData, Color) badgeFor(ItemHistoryEntry e) => switch (e.title) {
          'Sold' => (CupertinoIcons.bag, colors.ink.withValues(alpha: colors.isDark ? 0.35 : 0.55)),
          'Found' => (CupertinoIcons.search, colors.accent),
          _ when e.change > 0 => (CupertinoIcons.cube_box, colors.accent),
          _ => (CupertinoIcons.minus, colors.danger),
        };

    return GroupedSection(
      title: 'History',
      footer: hidden > 0 ? 'Showing the latest ${shown.length} of ${entries.length} changes.' : null,
      children: shown.isEmpty
          ? [const ValueRow(label: 'No changes recorded', tone: ValueTone.muted)]
          : [
              for (final e in shown)
                ValueRow(
                  leading: IconBadge(icon: badgeFor(e).$1, color: badgeFor(e).$2),
                  label: e.title,
                  labelLines: 1,
                  detail: e.detail == null
                      ? DateFormat('MMM d, y · h:mm a').format(e.at)
                      : '${DateFormat('MMM d, y').format(e.at)} · ${e.detail}',
                  value: e.change > 0 ? '+${e.change}' : '−${-e.change}',
                  tone: e.change > 0 ? ValueTone.positive : ValueTone.strong,
                ),
            ],
    );
  }
}
