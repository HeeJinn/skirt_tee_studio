import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/categories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/csv.dart';
import '../../../core/utils/csv_export.dart';
import '../../../core/utils/date_stamp.dart';
import '../../../data/datasources/local/item_image_storage.dart';
import '../../../domain/entities/item.dart';
import '../../../domain/entities/money_entry.dart';
import '../../../domain/entities/staff.dart';
import '../../../domain/repositories/stock_repository.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/item_thumbnail.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_pill.dart';
import 'widgets/adjust_stock_dialog.dart';
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

  Future<void> _openAddDialog() async {
    final result = await showDialog<Item>(context: context, builder: (_) => const ItemFormDialog());
    if (result != null && mounted) {
      await context.read<InventoryViewModel>().addItem(result);
      if (!mounted) return;
      await context
          .read<SessionViewModel>()
          .log('Added item "${result.name}" · stock ${result.qtyOnHand} · ${_peso.format(result.unitPrice)}');
    }
  }

  Future<void> _openEditDialog(Item item) async {
    final result = await showDialog<Item>(context: context, builder: (_) => ItemFormDialog(item: item));
    if (result != null && mounted) {
      await context.read<InventoryViewModel>().updateItem(result);
      if (!mounted) return;
      String cost(double? c) => c == null ? 'none' : _peso.format(c);
      final changes = [
        if (result.unitPrice != item.unitPrice)
          'price ${_peso.format(item.unitPrice)} → ${_peso.format(result.unitPrice)}',
        if (result.unitCost != item.unitCost) 'cost ${cost(item.unitCost)} → ${cost(result.unitCost)}',
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
      builder: (_) => ReceiveStockDialog(items: context.read<InventoryViewModel>().items, ownerNames: owners),
    );
    if (result == null || !mounted) return;
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('DELETE ITEM'),
        content: Text('Remove "${item.name}" from inventory? Past sales keep their record of it.$loss'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dialogContext.tokens.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE'),
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

  Future<void> _exportCsv() async {
    // Exports the full inventory, not just the current search/filter —
    // "export inventory" should mean all of it.
    final items = context.read<InventoryViewModel>().items;
    final threshold = context.read<SettingsViewModel>().lowStockThreshold;
    final csv = buildCsv(
      ['Name', 'Category', 'Bargain', 'Price', 'Qty On Hand', 'Low Stock'],
      [
        for (final item in items)
          [
            item.name,
            item.category,
            item.isBargain ? 'Yes' : 'No',
            item.unitPrice,
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
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text('Low stock ≤ $threshold'),
                ),
                IconButton(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  tooltip: 'Export CSV',
                ),
                OutlinedButton.icon(
                  onPressed: _openAddDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('ADD ITEM'),
                ),
                ElevatedButton.icon(
                  onPressed: _openReceiveDialog,
                  icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                  label: const Text('RECEIVE STOCK'),
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
                  options: [(null, 'All'), for (final c in kCategories) (c, c)],
                  selected: _categoryFilter,
                  onSelected: (c) => setState(() => _categoryFilter = c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(icon: Icons.inventory_2_outlined, message: 'No items found')
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
          Expanded(flex: _flexItem, child: Text('ITEM', style: style)),
          Expanded(flex: _flexPrice, child: Text('PRICE', style: style, textAlign: TextAlign.right)),
          Expanded(flex: _flexStock, child: Text('IN STOCK', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: AppSpacing.xl),
          Expanded(flex: _flexStatus, child: Text('STATUS', style: style)),
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
        ? const StatusPill(label: 'OUT OF STOCK', tone: PillTone.danger)
        : item.isLowStock(threshold)
            ? const StatusPill(label: 'LOW STOCK', tone: PillTone.warning)
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
                            if (item.isBargain) ...[
                              const SizedBox(width: AppSpacing.sm),
                              const StatusPill(label: 'SALE', tone: PillTone.accent),
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
                  Text(_peso.format(item.unitPrice), style: tabular),
                  if (onEdit != null)
                    Text(
                      item.unitCost == null ? 'no cost' : 'cost ${_peso.format(item.unitCost)}',
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
                      icon: const Icon(Icons.swap_vert, size: 18),
                      tooltip: 'Adjust stock',
                      onPressed: onAdjust,
                    ),
                  if (onEdit != null)
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: 'Edit', onPressed: onEdit),
                  if (onDelete != null)
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18), tooltip: 'Delete', onPressed: onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
