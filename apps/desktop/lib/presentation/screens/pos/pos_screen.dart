import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/categories.dart';
import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/sale.dart';
import '../../viewmodels/cart_view_model.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/sales_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../widgets/payment_icon.dart';
import '../../widgets/sale_price.dart';
import '../../widgets/success_check.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/item_thumbnail.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/screen_header.dart';
import 'cash_tender_dialog.dart';
import 'tender.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// Core function: browse items, build a cart, complete a sale (which
/// deducts stock). Highest-traffic screen: browse on the left, checkout
/// docked on the right as its own tonal zone, always visible.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  String _search = '';
  String? _categoryFilter;

  /// The sale just completed — shown with the success animation in the
  /// empty cart panel. Without change due it times out; with change it
  /// stays until the next sale starts (or Done), since the cashier is
  /// counting it out of the drawer and may glance back more than once.
  _SoldSummary? _justSold;
  Timer? _justSoldTimer;

  @override
  void dispose() {
    _justSoldTimer?.cancel();
    super.dispose();
  }

  void _dismissJustSold() {
    _justSoldTimer?.cancel();
    if (_justSold != null) setState(() => _justSold = null);
  }

  Future<void> _completeSale(PaymentMethod method) async {
    final cart = context.read<CartViewModel>();
    final total = cart.total;
    final count = cart.itemCount;

    double? received;
    if (method == PaymentMethod.cash) {
      received = await showCashTenderDialog(context, total: total);
      if (received == null || !mounted) return;
    }

    final ok = await cart.checkout(method, amountTendered: received);
    if (!mounted || !ok) return;
    await Future.wait([
      context.read<InventoryViewModel>().load(),
      context.read<SalesViewModel>().load(),
      context.read<SessionViewModel>().log([
        'Sale ${_peso.format(total)}',
        '$count item${count == 1 ? '' : 's'}',
        method.label,
        if (received != null) 'received ${_peso.format(received)}',
      ].join(' · ')),
    ]);
    if (!mounted) return;
    final summary = (total: total, method: method, received: received);
    setState(() => _justSold = summary);
    _justSoldTimer?.cancel();
    if (!summary.hasChange) {
      _justSoldTimer = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _justSold = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryViewModel>().items;
    final items = inventory.where((item) {
      final matchesSearch = _search.isEmpty || item.name.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory = _categoryFilter == null || item.category == _categoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
    final inStock = inventory.where((i) => i.qtyOnHand > 0).length;
    final cart = context.watch<CartViewModel>();
    final lowStockThreshold = context.watch<SettingsViewModel>().lowStockThreshold;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(title: 'POS', subtitle: '$inStock of ${inventory.length} items in stock'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Flexible(
                      flex: 2,
                      child: SearchField(hint: 'Search items', onChanged: (v) => setState(() => _search = v), width: 260),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 3,
                      child: ChoiceStrip<String?>(
                        // Only categories with something to sell.
                        options: [
                          (null, 'All'),
                          for (final c in categoryOptions(context.watch<SettingsViewModel>().categories, inventory))
                            if (inventory.any((i) => i.category == c)) (c, c),
                        ],
                        selected: _categoryFilter,
                        onSelected: (c) => setState(() => _categoryFilter = c),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: items.isEmpty
                      ? const EmptyState(icon: CupertinoIcons.search, message: 'No items match this search')
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 196,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.76,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final item = items[i];
                            final inCart = cart.qtyInCart(item.id);
                            final available = item.qtyOnHand - inCart;
                            return _ItemTile(
                              item: item,
                              inCart: inCart,
                              available: available,
                              isLow: item.qtyOnHand > 0 && item.isLowStock(lowStockThreshold),
                              onTap: available > 0
                                  ? () {
                                      _dismissJustSold();
                                      cart.addItem(item);
                                    }
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        _CartPanel(onCompleteSale: _completeSale, justSold: _justSold, onDismissJustSold: _dismissJustSold),
      ],
    );
  }
}

class _ItemTile extends StatefulWidget {
  const _ItemTile({
    required this.item,
    required this.inCart,
    required this.available,
    required this.isLow,
    required this.onTap,
  });

  final Item item;
  final int inCart;
  final int available;
  final bool isLow;
  final VoidCallback? onTap;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _hovered = false;
  bool _pressed = false;

  /// Last non-zero count, so the badge shows "×2" (not "×0") while it
  /// scales away after the cart clears.
  int _badgeQty = 0;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final disabled = widget.onTap == null;
    if (widget.inCart > 0) _badgeQty = widget.inCart;
    final tokens = context.tokens;

    final (stockLabel, stockColor) = switch (item) {
      _ when item.qtyOnHand <= 0 => ('Sold out', tokens.danger),
      _ when widget.available <= 0 => ('All in cart', tokens.mutedText),
      _ when widget.isLow => ('${widget.available} left', tokens.warning),
      _ => ('${widget.available} left', tokens.mutedText),
    };

    // A product card as the Apple Store app sets one: the photo flush at
    // the top, name and price beneath, on the card color with no border.
    // Hovering lifts it a touch; pressing sinks it.
    final shape = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.container));
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: context.colors.surface,
            shape: shape,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered && !disabled ? 0.12 : 0.0),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Opacity(
                opacity: disabled ? 0.45 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ItemThumbnail(imagePath: item.imagePath, name: item.name, radius: 0),
                          if (item.onSale) Positioned(top: 8, left: 8, child: SalePill(item: item)),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: AnimatedScale(
                              scale: widget.inCart > 0 ? 1 : 0,
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutBack,
                              child: _InCartBadge(qty: _badgeQty),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 40,
                            child: Text(
                              item.name,
                              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // The price keeps its size unless the card is
                              // too narrow for it and the stock line.
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: SalePriceText(
                                    item: item,
                                    style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                stockLabel,
                                style: context.text.bodySmall?.copyWith(
                                  color: stockColor,
                                  fontWeight: stockColor == tokens.mutedText ? FontWeight.w400 : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows how many of this item are already in the sale, right on the tile.
class _InCartBadge extends StatelessWidget {
  const _InCartBadge({required this.qty});
  final int qty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(color: context.colors.primary, shape: const StadiumBorder()),
      child: Text(
        '×$qty',
        style: TextStyle(
          fontFamily: kSansFont,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.colors.onPrimary,
          fontFeatures: kTabularFigures,
        ),
      ),
    );
  }
}

typedef _SoldSummary = ({double total, PaymentMethod method, double? received});

extension on _SoldSummary {
  double? get change => received == null ? null : changeDue(received!, total);
  bool get hasChange => (change ?? 0) > 0;
}

/// The sale being rung up, docked on the right as iPadOS docks an
/// inspector: its own rounded pane inset from the window's edges, the
/// lines scrolling in the middle, and the total and tenders held at the
/// foot within reach.
class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.onCompleteSale, required this.justSold, required this.onDismissJustSold});
  final ValueChanged<PaymentMethod> onCompleteSale;
  final _SoldSummary? justSold;
  final VoidCallback onDismissJustSold;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final tokens = context.tokens;
    final count = cart.itemCount;

    return Container(
      width: 372,
      margin: const EdgeInsets.fromLTRB(0, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: ShapeDecoration(
        color: context.colors.surface,
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current sale', style: context.text.titleLarge),
                    Text(
                      count == 0 ? 'No items yet' : '$count item${count == 1 ? '' : 's'}',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!cart.isEmpty) TextButton(onPressed: cart.clear, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          Expanded(
            child: cart.isEmpty
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: justSold == null
                        ? const EmptyState(
                            icon: CupertinoIcons.bag,
                            title: 'No Items',
                            message: 'Tap an item to start a sale',
                          )
                        : _SaleCompleteView(key: ValueKey(justSold), sold: justSold!, onDone: onDismissJustSold),
                  )
                : ListView.separated(
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => _CartLineRow(line: cart.lines[i]),
                  ),
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Total', style: context.text.titleMedium?.copyWith(color: tokens.mutedText)),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: Text(
                  _peso.format(cart.total),
                  key: ValueKey(cart.total),
                  style: context.text.displaySmall?.copyWith(fontFeatures: kTabularFigures),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // One button per tender instead of "complete" + a default: the
          // method is always a deliberate choice, and it's still one click.
          Text('Complete sale · paid by', style: context.text.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          for (var row = 0; row < PaymentMethod.selectable.length; row += 2) ...[
            if (row > 0) const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 50,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, method) in PaymentMethod.selectable.skip(row).take(2).indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      // Cash is the everyday tender, so it alone is the
                      // accent capsule; the rest are grey — same one click,
                      // less weight.
                      child: method == PaymentMethod.cash
                          ? ElevatedButton.icon(
                              onPressed: cart.isEmpty ? null : () => onCompleteSale(method),
                              style: ElevatedButton.styleFrom(textStyle: context.text.titleMedium),
                              icon: Icon(paymentIcon(method), size: 20),
                              label: Text(method.label),
                            )
                          : OutlinedButton.icon(
                              onPressed: cart.isEmpty ? null : () => onCompleteSale(method),
                              style: OutlinedButton.styleFrom(textStyle: context.text.titleMedium),
                              icon: Icon(paymentIcon(method), size: 20),
                              label: Text(method.label),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartViewModel>();
    final atStockLimit = line.qty >= line.item.qtyOnHand;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.name,
                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                SalePriceText(item: line.item, suffix: ' each', style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _QtyStepper(
            qty: line.qty,
            onDecrement: () => cart.decrementItem(line.item.id),
            onIncrement: atStockLimit ? null : () => cart.addItem(line.item),
          ),
          SizedBox(
            width: 84,
            child: Text(
              _peso.format(line.subtotal),
              textAlign: TextAlign.right,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: kTabularFigures),
            ),
          ),
        ],
      ),
    );
  }
}

/// An iOS stepper: − and + in one grey capsule, the count between them.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onDecrement, required this.onIncrement});

  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, VoidCallback? onPressed, String tooltip) => IconButton(
          icon: Icon(icon, size: 16),
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: const BoxConstraints.tightFor(width: 34, height: 32),
          padding: EdgeInsets.zero,
          color: context.colors.onSurface,
        );

    return Container(
      decoration: ShapeDecoration(color: context.tokens.sunken, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step(CupertinoIcons.minus, onDecrement, 'Remove one'),
          SizedBox(
            width: 24,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: kTabularFigures),
            ),
          ),
          step(CupertinoIcons.add, onIncrement, 'Add one'),
        ],
      ),
    );
  }
}

/// Success state in the empty cart panel. With change due, the change is the
/// headline — big, with the bills and coins to pull — since that's what the
/// cashier needs next.
class _SaleCompleteView extends StatelessWidget {
  const _SaleCompleteView({super.key, required this.sold, required this.onDone});
  final _SoldSummary sold;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final summary = Text(
      '${_peso.format(sold.total)} · ${sold.method.label}',
      style: context.text.bodyMedium?.copyWith(color: tokens.mutedText),
    );

    if (!sold.hasChange) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SuccessCheck(),
            const SizedBox(height: AppSpacing.md),
            Text('Sale complete', style: context.text.titleLarge),
            summary,
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SuccessCheck(size: 64)),
            const SizedBox(height: AppSpacing.sm),
            Center(child: Text('Sale complete', style: context.text.titleLarge)),
            Center(child: summary),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: ShapeDecoration(
                color: tokens.sunken,
                shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.container - 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Change due', style: context.text.labelSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _peso.format(sold.change),
                    style: context.text.displaySmall?.copyWith(fontFeatures: kTabularFigures),
                  ),
                  Text('from ${_peso.format(sold.received)} received', style: context.text.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  ChangeBreakdownChips(change: sold.change!),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(child: TextButton(onPressed: onDone, child: const Text('Done'))),
          ],
        ),
      ),
    );
  }
}
