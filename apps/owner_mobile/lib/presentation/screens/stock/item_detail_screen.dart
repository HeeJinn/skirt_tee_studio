import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/item.dart';

import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/stock_view_model.dart';
import '../../widgets/item_photo.dart';
import '../../widgets/ui/badges.dart';
import '../../widgets/ui/glass.dart';
import '../../widgets/ui/section.dart';
import 'item_history.dart';
import 'item_history_screen.dart';

/// One item: its photo, what it sells for and costs, how much is left and
/// how fast it's selling, and every change to its stock. Looked up by id, so
/// an item removed on the shop computer while open says so.
///
/// With a photo, the photo runs edge to edge up under the status bar, with
/// only a glass back button floating on it, as iOS 26 lets content fill the
/// screen; the item's name fades in on a bar once the photo scrolls away.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  /// History rows shown here; the rest are a tap away.
  static const historyPreview = 5;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _scroll = ScrollController();
  bool _pastPhoto = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The square photo is as tall as the screen is wide; the bar shows once
  /// the photo has gone up under where the bar would be.
  void _onScroll() {
    final media = MediaQuery.of(context);
    final past = _scroll.offset > media.size.width - media.padding.top - 52;
    if (past != _pastPhoto) setState(() => _pastPhoto = past);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockViewModel>();
    final item = vm.byId(widget.itemId);
    final media = MediaQuery.of(context);

    if (item == null) {
      return CupertinoPageScaffold(
        navigationBar: shopNavBar(title: 'Item', backTo: 'Stock'),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Text('This item was removed on the shop computer.', style: ShopType.subhead(context)),
          ),
        ),
      );
    }

    final sections = [
      _Title(item: item),
      _Figures(item: item),
      _Details(item: item),
      _History(itemId: item.id, entries: vm.historyOf(item.id)),
    ];

    if (item.imagePath == null) {
      return CupertinoPageScaffold(
        navigationBar: shopNavBar(title: item.name, backTo: 'Stock'),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.only(bottom: media.padding.bottom + Space.lg),
            children: sections,
          ),
        ),
      );
    }

    final colors = ShopColors.of(context);
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          ListView(
            controller: _scroll,
            padding: EdgeInsets.only(bottom: media.padding.bottom + Space.lg),
            children: [
              AspectRatio(aspectRatio: 1, child: ItemPhoto(imagePath: item.imagePath, name: item.name)),
              ...sections,
            ],
          ),
          // The bar, once the photo has scrolled away: blurred page tone
          // with the name, the way a large title collapses.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: Motion.medium,
                curve: Motion.curve,
                opacity: _pastPhoto ? 1 : 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: media.padding.top + 52,
                      padding: EdgeInsets.fromLTRB(64, media.padding.top, 64, 0),
                      alignment: Alignment.center,
                      color: colors.page.withValues(alpha: 0.8),
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: Space.md,
            top: media.padding.top + 6,
            child: const ShopBackButton(to: 'Stock'),
          ),
        ],
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
              if (item.onSale)
                Pill(text: item.percentOff == null ? 'Sale' : 'Sale −${item.percentOff}%', color: colors.accent),
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
    // On sale, both figures are at the sale price — what a piece brings in now.
    final price = item.sellingPrice;
    final margin = cost == null ? null : price - cost;
    final figures = [
      ('On hand', '${item.qtyOnHand > 0 ? item.qtyOnHand : 0}', null),
      ('Sells for', pesoWhole.format(price), item.isMarkedDown ? 'was ${pesoWhole.format(item.unitPrice)}' : null),
      (
        'Makes each',
        margin == null ? '—' : signedPeso(margin, whole: true),
        margin == null || price == 0 ? 'cost unknown' : '${(margin / price * 100).round()}% margin',
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

/// The latest few changes, and the way into the full history, which can
/// be narrowed to a month or a day.
class _History extends StatelessWidget {
  const _History({required this.itemId, required this.entries});
  final String itemId;
  final List<ItemHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final shown = entries.take(ItemDetailScreen.historyPreview).toList();

    return GroupedSection(
      title: 'History',
      children: shown.isEmpty
          ? [const ValueRow(label: 'No changes recorded', tone: ValueTone.muted)]
          : [
              for (final e in shown)
                ItemHistoryRow(
                  entry: e,
                  when: DateFormat(e.detail == null ? 'MMM d, y · h:mm a' : 'MMM d, y').format(e.at),
                ),
              ValueRow(
                leading: const Icon(CupertinoIcons.calendar, size: 20),
                label: 'All history',
                value: '${entries.length}',
                tone: ValueTone.muted,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(builder: (_) => ItemHistoryScreen(itemId: itemId)),
                ),
              ),
            ],
    );
  }
}
