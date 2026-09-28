import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/categories.dart';
import 'package:shop_core/core/theme/app_theme.dart';
import '../../../core/utils/csv.dart';
import '../../../core/utils/csv_export.dart';
import '../../../core/utils/date_stamp.dart';
import 'package:shop_core/data/datasources/local/item_image_storage.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/staff.dart';
import 'package:shop_core/domain/repositories/stock_repository.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/ios_alert.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/item_thumbnail.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/sale_price.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_pill.dart';
import 'widgets/adjust_stock_dialog.dart';
import 'widgets/categories_dialog.dart';
import 'widgets/item_form_dialog.dart';
import 'widgets/low_stock_threshold_dialog.dart';
import 'widgets/receive_stock_dialog.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// Core function: view/add/edit items, see stock levels. Dense, scannable
/// table — this is reference data, not a browsing surface like POS.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';
  String? _categoryFilter;

  List<String> get _categories =>
      categoryOptions(context.read<SettingsViewModel>().categories, context.read<InventoryViewModel>().items);

  /// A category typed in with "New category…" joins the shop's list.
  Future<void> _keepCategories(Iterable<Item> items) =>
      context.read<SettingsViewModel>().addCategories(items.map((i) => i.category));

  Future<void> _openAddDialog() async {
    final result = await showDialog<Item>(
      context: context,
      builder: (_) => ItemFormDialog(categories: _categories),
    );
    if (result != null && mounted) {
      await _keepCategories([result]);
      if (!mounted) return;
      await context.read<InventoryViewModel>().addItem(result);
      if (!mounted) return;
      await context
          .read<SessionViewModel>()
          .log('Added item "${result.name}" · stock ${result.qtyOnHand} · ${_peso.format(result.unitPrice)}');
    }
  }

  Future<void> _openEditDialog(Item item) async {
    final result = await showDialog<Item>(
      context: context,
      builder: (_) => ItemFormDialog(item: item, categories: _categories),
    );
    if (result != null && mounted) {
      await _keepCategories([result]);
      if (!mounted) return;
      await context.read<InventoryViewModel>().updateItem(result);
      if (!mounted) return;
      String cost(double? c) => c == null ? 'none' : _peso.format(c);
      final changes = [
        if (result.unitPrice != item.unitPrice)
          'price ${_peso.format(item.unitPrice)} → ${_peso.format(result.unitPrice)}',
        if (result.unitCost != item.unitCost) 'cost ${cost(item.unitCost)} → ${cost(result.unitCost)}',
        if (result.onSale != item.onSale || result.sellingPrice != item.sellingPrice)
          result.onSale ? 'on sale at ${_peso.format(result.sellingPrice)}' : 'sale ended',
      ];
      await context
          .read<SessionViewModel>()
          .log('Edited item "${result.name}"${changes.isEmpty ? '' : ' · ${changes.join(' · ')}'}');
    }
  }

  Future<void> _openReceiveDialog() async {
    final owners = context
        .read<SessionViewModel>()
        .staff
        .where((s) => s.role == StaffRole.owner)
        .map((s) => s.name)
        .toList();
    final result = await showDialog<ReceivedLot>(
      context: context,
      builder: (_) => ReceiveStockDialog(
        items: context.read<InventoryViewModel>().items,
        ownerNames: owners,
        categories: _categories,
      ),
    );
    if (result == null || !mounted) return;
    await _keepCategories(result.newItems);
    if (!mounted) return;
    try {
      await context.read<InventoryViewModel>().receiveLot(result.lot, result.lines, newItems: result.newItems);
    } on StockChangeException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
      return;
    }
    if (!mounted) return;
    final lot = result.lot;
    final paidBy = lot.paidFrom == PaidFrom.owners ? ' · paid by ${lot.person ?? 'both owners'}' : '';
    await context.read<SessionViewModel>().log(
          'Received ${result.pieces} pieces'
          '${lot.supplier.isEmpty ? '' : ' from ${lot.supplier}'} · ${_peso.format(lot.totalCost)}$paidBy',
        );
    if (mounted) showAppSnackBar(context, 'Received ${result.pieces} pieces');
  }

  Future<void> _openAdjustDialog(Item item) async {
    final result = await showDialog<StockAdjustment>(context: context, builder: (_) => AdjustStockDialog(item: item));
    if (result == null || !mounted) return;
    try {
      await context
          .read<InventoryViewModel>()
          .adjustStock(item.id, result.qty, reason: result.reason, note: result.note);
    } on StockChangeException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
      return;
    }
    if (!mounted) return;
    await context.read<SessionViewModel>().log(result.isFound
        ? 'Found ${result.qty} of "${item.name}"'
        : 'Removed ${result.qty} of "${item.name}" · ${result.reason!.label}'
            '${result.note.isEmpty ? '' : ' · ${result.note}'}');
  }

  Future<void> _confirmDelete(Item item) async {
    final loss = item.qtyOnHand > 0 && item.unitCost != null
        ? ' The ${item.qtyOnHand} still in stock will be recorded as a ${_peso.format(item.qtyOnHand * item.unitCost!)} loss.'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => IosAlert(
        title: const Text('Delete Item'),
        content: Text('Remove "${item.name}" from inventory? Past sales keep their record of it.$loss'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dialogContext.tokens.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<InventoryViewModel>().deleteItem(item.id);
      if (!mounted) return;
      await context.read<SessionViewModel>().log('Deleted item "${item.name}" · had ${item.qtyOnHand} in stock');
      if (item.imagePath != null) {
        await ItemImageStorage.instance.delete(item.imagePath!);
      }
    }
  }

  Future<void> _openThresholdDialog() async {
    final settings = context.read<SettingsViewModel>();
    final result = await showDialog<int>(
      context: context,
      builder: (_) => LowStockThresholdDialog(currentThreshold: settings.lowStockThreshold),
    );
    if (result != null && mounted) {
      await settings.updateLowStockThreshold(result);
      if (!mounted) return;
      await context.read<SessionViewModel>().log('Set low-stock threshold to $result');
    }
  }

  Future<void> _openCategoriesDialog() async {
    final settings = context.read<SettingsViewModel>();
    final itemCounts = <String, int>{};
    for (final item in context.read<InventoryViewModel>().items) {
      itemCounts.update(item.category, (v) => v + 1, ifAbsent: () => 1);
    }
    final before = _categories;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => CategoriesDialog(categories: before, itemCounts: itemCounts),
    );
    if (result == null || !mounted) return;
    await settings.saveCategories(result);
    if (!mounted) return;
    final added = result.where((c) => !before.contains(c));
    final removed = before.where((c) => !result.contains(c));
    if (added.isEmpty && removed.isEmpty) return;
    await context.read<SessionViewModel>().log([
      if (added.isNotEmpty) 'Added categories ${added.join(', ')}',
      if (removed.isNotEmpty) 'Removed categories ${removed.join(', ')}',
    ].join(' · '));
  }

  Future<void> _exportCsv() async {
    // Exports the full inventory, not just the current search/filter —
    // "export inventory" should mean all of it.
    final items = context.read<InventoryViewModel>().items;
    final threshold = context.read<SettingsViewModel>().lowStockThreshold;
    final csv = buildCsv(
      ['Name', 'Category', 'Price', 'On Sale', 'Sale Price', 'Qty On Hand', 'Low Stock'],
      [
        for (final item in items)
          [
            item.name,
            item.category,
            item.unitPrice,
            item.onSale ? 'Yes' : 'No',
            item.onSale ? item.sellingPrice : '',
            item.qtyOnHand,
            item.isLowStock(threshold) ? 'Yes' : 'No',
          ],
      ],
    );
    await exportCsv(context, suggestedName: 'inventory_${dateStamp(DateTime.now())}.csv', csv: csv);
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<InventoryViewModel>().items;
    final items = all.where((item) {
      final matchesSearch = _search.isEmpty || item.name.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory = _categoryFilter == null || item.category == _categoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
    final threshold = context.watch<SettingsViewModel>().lowStockThreshold;
    final canEdit = context.watch<SessionViewModel>().isOwner;
    final categories = categoryOptions(context.watch<SettingsViewModel>().categories, all);

    final units = all.fold(0, (sum, i) => sum + i.qtyOnHand);
    final out = all.where((i) => i.qtyOnHand <= 0).length;
    final low = all.where((i) => i.qtyOnHand > 0 && i.isLowStock(threshold)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Inventory',
            subtitle: '${all.length} items · $units units in stock · $low low · $out out of stock',
            actions: [
              if (canEdit) ...[
                TextButton.icon(
                  onPressed: _openThresholdDialog,
                  icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 18),
                  label: Text('Low stock ≤ $threshold'),
                ),
                IconButton(
                  onPressed: _exportCsv,
                  icon: const Icon(CupertinoIcons.square_arrow_down, size: 20),
                  tooltip: 'Export CSV',
                ),
                OutlinedButton.icon(
                  onPressed: _openAddDialog,
                  icon: const Icon(CupertinoIcons.add, size: 18),
                  label: const Text('Add Item'),
                ),
                ElevatedButton.icon(
                  onPressed: _openReceiveDialog,
                  icon: const Icon(CupertinoIcons.tray_arrow_down, size: 18),
                  label: const Text('Receive Stock'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SearchField(hint: 'Search items', onChanged: (v) => setState(() => _search = v)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: ChoiceStrip<String?>(
                  options: [(null, 'All'), for (final c in categories) (c, c)],
                  selected: _categoryFilter,
                  onSelected: (c) => setState(() => _categoryFilter = c),
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: _openCategoriesDialog,
                  icon: const Icon(CupertinoIcons.square_pencil, size: 22),
                  tooltip: 'Add or remove categories',
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(icon: CupertinoIcons.cube_box, message: 'No items found')
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ListSurface(
                      header: const _InventoryHeaderRow(),
                      children: [
                        for (final item in items)
                          _InventoryRow(
                            item: item,
                            threshold: threshold,
                            onEdit: canEdit ? () => _openEditDialog(item) : null,
                            onAdjust: canEdit ? () => _openAdjustDialog(item) : null,
                            onDelete: canEdit ? () => _confirmDelete(item) : null,
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Shared column geometry for the header and every row.
const _flexItem = 6;
const _flexPrice = 2;
const _flexStock = 2;
const _flexStatus = 3;
const _actionsWidth = 144.0; // three 48px icon buttons — full-size hit targets
const _rowPadding = EdgeInsets.symmetric(horizontal: AppSpacing.lg);

class _InventoryHeaderRow extends StatelessWidget {
  const _InventoryHeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelSmall;
    return Padding(
      padding: _rowPadding.add(const EdgeInsets.symmetric(vertical: 10)),
      child: Row(
        children: [
          Expanded(flex: _flexItem, child: Text('Item', style: style)),
          Expanded(flex: _flexPrice, child: Text('Sells for', style: style, textAlign: TextAlign.right)),
          Expanded(flex: _flexStock, child: Text('In stock', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: AppSpacing.xl),
          Expanded(flex: _flexStatus, child: Text('Status', style: style)),
          const SizedBox(width: _actionsWidth),
        ],
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.item,
    required this.threshold,
    required this.onEdit,
    required this.onAdjust,
    required this.onDelete,
  });

  final Item item;
  final int threshold;
  /// Null for read-only (cashier) viewers — the row isn't editable, and
  /// cost stays hidden.
  final VoidCallback? onEdit;
  final VoidCallback? onAdjust;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tabular = context.text.bodyMedium?.copyWith(fontFeatures: kTabularFigures);
    final Widget status = item.qtyOnHand <= 0
        ? const StatusPill(label: 'Out of stock', tone: PillTone.danger)
        : item.isLowStock(threshold)
            ? const StatusPill(label: 'Low stock', tone: PillTone.warning)
            : const SizedBox.shrink();

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: _rowPadding.add(const EdgeInsets.symmetric(vertical: 10)),
        child: Row(
          children: [
            Expanded(
              flex: _flexItem,
              child: Row(
                children: [
                  ItemThumbnail(imagePath: item.imagePath, name: item.name, size: 40),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.onSale) ...[
                              const SizedBox(width: AppSpacing.sm),
                              SalePill(item: item),
                            ],
                          ],
                        ),
                        Text(item.category, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: _flexPrice,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SalePriceText(item: item, style: tabular),
                  if (onEdit != null)
                    Text(
                      item.unitCost == null ? 'cost not set' : 'paid ${_peso.format(item.unitCost)}',
                      style: context.text.bodySmall?.copyWith(fontFeatures: kTabularFigures),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: _flexStock,
              child: Text('${item.qtyOnHand}', style: tabular, textAlign: TextAlign.right),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(flex: _flexStatus, child: Align(alignment: Alignment.centerLeft, child: status)),
            SizedBox(
              width: _actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onAdjust != null)
                    IconButton(
                      icon: const Icon(CupertinoIcons.arrow_up_arrow_down, size: 18),
                      tooltip: 'Adjust stock',
                      onPressed: onAdjust,
                    ),
                  if (onEdit != null)
                    IconButton(icon: const Icon(CupertinoIcons.pencil, size: 18), tooltip: 'Edit', onPressed: onEdit),
                  if (onDelete != null)
                    IconButton(icon: const Icon(CupertinoIcons.trash, size: 18), tooltip: 'Delete', onPressed: onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
