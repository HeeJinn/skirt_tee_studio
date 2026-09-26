import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/item.dart';

import '../../../core/theme/cupertino_theme.dart';
import '../../viewmodels/stock_view_model.dart';
import '../../widgets/item_photo.dart';
import 'item_detail_screen.dart';

/// Every item in a photo grid, searchable, and filtered by how much is left.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockViewModel>();
    final items = vm.items;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    String label(StockFilter f, String name) {
      final n = vm.count(f);
      return f == StockFilter.all || n == 0 ? name : '$name ($n)';
    }

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Stock')),
          CupertinoSliverRefreshControl(onRefresh: context.read<StockViewModel>().load),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoSearchTextField(placeholder: 'Search items', onChanged: vm.search),
                  const SizedBox(height: 10),
                  CupertinoSlidingSegmentedControl<StockFilter>(
                    groupValue: vm.filter,
                    onValueChanged: (f) {
                      if (f != null) vm.selectFilter(f);
                    },
                    children: {
                      for (final (f, name) in const [
                        (StockFilter.all, 'All'),
                        (StockFilter.low, 'Low'),
                        (StockFilter.soldOut, 'Sold out'),
                      ])
                        f: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label(f, name))),
                        ),
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${vm.count(StockFilter.all)} items · ${vm.totalPieces} pieces on hand',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                ],
              ),
            ),
          ),
          if (!vm.loaded)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator()))
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    vm.query.trim().isNotEmpty
                        ? 'No items match "${vm.query.trim()}".'
                        : switch (vm.filter) {
                            StockFilter.all => 'No items yet. They show up here once added on the shop computer.',
                            StockFilter.low => 'Nothing is running low.',
                            StockFilter.soldOut => 'Nothing is sold out.',
                          },
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: secondary),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => _ItemCard(item: items[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<StockViewModel>();
    final tokens = shopTokens(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final (stockText, stockColor) = vm.isSoldOut(item)
        ? ('Sold out', tokens.danger)
        : vm.isLow(item)
            ? ('${item.qtyOnHand} left', tokens.warning)
            : ('${item.qtyOnHand} left', secondary);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: item.id)),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ItemPhoto(imagePath: item.imagePath, name: item.name)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${peso.format(item.unitPrice)} · $stockText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: stockColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
