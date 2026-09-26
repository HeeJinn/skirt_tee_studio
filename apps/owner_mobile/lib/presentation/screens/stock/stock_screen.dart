import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/item.dart';

import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/stock_view_model.dart';
import '../../widgets/item_photo.dart';
import '../../widgets/ui/badges.dart';
import '../../widgets/ui/empty_state.dart';
import '../../widgets/ui/line_art.dart';
import '../../widgets/ui/section.dart';
import 'item_detail_screen.dart';

/// Every item in a photo grid, searchable, and filtered by how much is left.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockViewModel>();
    final items = vm.items;

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
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoSearchTextField(placeholder: 'Search items', onChanged: vm.search),
                  const SizedBox(height: Space.md),
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
                          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label(f, name))),
                        ),
                    },
                  ),
                  const SizedBox(height: Space.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    child: Text(
                      '${vm.count(StockFilter.all)} items · ${vm.totalPieces} pieces on hand',
                      style: ShopType.footnote(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!vm.loaded)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator()))
          else if (vm.count(StockFilter.all) == 0)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                drawing: LineArtDrawing.tee,
                message: 'No items yet. They show up here once added on the shop computer.',
              ),
            )
          else if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xs, Space.lg, Space.gutter + Space.xs, 0),
                child: Text(
                  vm.query.trim().isNotEmpty
                      ? 'No items match "${vm.query.trim()}".'
                      : switch (vm.filter) {
                          StockFilter.all => 'No items.',
                          StockFilter.low => 'Nothing is running low.',
                          StockFilter.soldOut => 'Nothing is sold out.',
                        },
                  style: ShopType.subhead(context),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 0),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: Space.lg,
                  crossAxisSpacing: Space.md,
                  childAspectRatio: 0.66,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => _ItemCard(item: items[i]),
              ),
            ),
          const SliverToBoxAdapter(child: BottomInset()),
        ],
      ),
    );
  }
}

/// A photo with its stock status on it, and the name and price beneath —
/// no card chrome around the text, so the photos carry the grid.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<StockViewModel>();
    final colors = ShopColors.of(context);
    final status = vm.isSoldOut(item)
        ? Pill(text: 'Sold out', color: colors.danger, solid: true)
        : vm.isLow(item)
            ? Pill(text: '${item.qtyOnHand} left', color: colors.warning, solid: true)
            : null;

    return Pressable(
      scale: true,
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: item.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.photo),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ItemPhoto(imagePath: item.imagePath, name: item.name),
                  if (status != null) Positioned(left: Space.sm, top: Space.sm, child: status),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ShopType.body(context).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            vm.isSoldOut(item) ? peso.format(item.unitPrice) : '${peso.format(item.unitPrice)} · ${item.qtyOnHand} on hand',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ShopType.footnote(context).copyWith(fontFeatures: ShopType.tabular),
          ),
        ],
      ),
    );
  }
}
