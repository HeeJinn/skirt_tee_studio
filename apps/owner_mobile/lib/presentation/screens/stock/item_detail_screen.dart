import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/item.dart';

import '../../../core/theme/cupertino_theme.dart';
import '../../viewmodels/stock_view_model.dart';
import '../../widgets/item_photo.dart';
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
        child: item == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'This item was removed on the shop computer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (item.imagePath != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(aspectRatio: 1, child: ItemPhoto(imagePath: item.imagePath, name: item.name)),
                      ),
                    ),
                  _Title(item: item),
                  _Price(item: item),
                  _Stock(item: item),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              item.isBargain ? '${item.category} · Bargain' : item.category,
              style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ],
        ),
      );
}

class _Price extends StatelessWidget {
  const _Price({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final cost = item.unitCost;
    final margin = cost == null ? null : item.unitPrice - cost;
    final marginShare = margin == null || item.unitPrice == 0 ? null : margin / item.unitPrice;
    return CupertinoListSection.insetGrouped(
      header: const Text('PRICE'),
      footer: cost == null ? const Text('No cost recorded yet, so what this item makes is unknown.') : null,
      children: [
        CupertinoListTile(title: const Text('Sells for'), additionalInfo: Text(peso.format(item.unitPrice))),
        CupertinoListTile(
          title: const Text('Costs'),
          additionalInfo: Text(cost == null ? 'Not recorded' : '${peso.format(cost)} each'),
        ),
        if (margin != null)
          CupertinoListTile(
            title: const Text('Makes per piece'),
            additionalInfo: Text(
              marginShare == null ? signedPeso(margin) : '${signedPeso(margin)} (${(marginShare * 100).round()}%)',
              style: TextStyle(color: margin < 0 ? shopTokens(context).danger : null),
            ),
          ),
      ],
    );
  }
}

class _Stock extends StatelessWidget {
  const _Stock({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<StockViewModel>();
    final tokens = shopTokens(context);
    final cost = item.unitCost;
    final onHand = item.qtyOnHand > 0 ? item.qtyOnHand : 0;
    final (status, color) = vm.isSoldOut(item)
        ? ('Sold out', tokens.danger)
        : vm.isLow(item)
            ? ('$onHand · low', tokens.warning)
            : ('$onHand', null);
    final sold = vm.soldInLast30Days(item.id);
    return CupertinoListSection.insetGrouped(
      header: const Text('STOCK'),
      children: [
        CupertinoListTile(title: const Text('On hand'), additionalInfo: Text(status, style: TextStyle(color: color))),
        if (cost != null)
          CupertinoListTile(title: const Text('Worth, at cost'), additionalInfo: Text(peso.format(onHand * cost))),
        CupertinoListTile(
          title: const Text('Sold, last 30 days'),
          additionalInfo: Text('$sold ${sold == 1 ? 'piece' : 'pieces'}'),
        ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.entries});
  final List<ItemHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = shopTokens(context);
    final shown = entries.take(ItemDetailScreen.historyLimit).toList();
    final hidden = entries.length - shown.length;
    return CupertinoListSection.insetGrouped(
      header: const Text('HISTORY'),
      footer: hidden > 0 ? Text('Showing the latest ${shown.length} of ${entries.length} changes.') : null,
      children: shown.isEmpty
          ? [const CupertinoListTile(title: Text('No changes recorded'))]
          : [
              for (final e in shown)
                CupertinoListTile(
                  title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    e.detail == null
                        ? DateFormat('MMM d, y · h:mm a').format(e.at)
                        : '${DateFormat('MMM d, y').format(e.at)} · ${e.detail}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  additionalInfo: Text(
                    e.change > 0 ? '+${e.change}' : '−${-e.change}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: e.change > 0 ? tokens.success : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
            ],
    );
  }
}
