import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import '../../../../core/utils/money_input.dart';
import 'package:shop_core/data/datasources/local/item_image_storage.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/repositories/settings_repository.dart';
import '../../../widgets/filter_bar.dart';
import '../../../widgets/item_thumbnail.dart';
import 'category_field.dart';

const _imageTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: ['jpg', 'jpeg', 'png', 'webp'],
);

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// How a sale's discount is set.
enum _SaleBy { percent, price }

/// Add/Edit Item dialog. Pass an existing [item] to edit it in place;
/// omit it to create a new one. Returns the resulting Item via Navigator.pop,
/// or null if cancelled.
///
/// An existing item's quantity is read-only here: stock only changes through
/// Receive stock / Adjust stock, so every piece in or out is costed.
///
/// What a piece cost is normally set by Receive stock, so the form keeps it
/// out of the way: a new item only asks for it when it already has pieces on
/// hand, and an existing item shows it as text behind a Set/Change link.
class ItemFormDialog extends StatefulWidget {
  const ItemFormDialog({
    super.key,
    this.item,
    this.forLot = false,
    this.categories = SettingsRepository.defaultCategories,
  });
  final Item? item;

  /// What the category dropdown offers. One typed in with "New category…"
  /// comes back on the item; the caller adds it to the shop's list.
  final List<String> categories;

  /// Creating an item that arrived in a lot being received: no quantity or
  /// cost fields, since the lot supplies both.
  final bool forLot;

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _qtyController;
  late final TextEditingController _costController;
  late final TextEditingController _saleController;
  late String _category;
  late bool _onSale;
  late _SaleBy _saleBy;
  late String? _imagePath;

  /// Editing only: the owner tapped Set/Change cost.
  bool _editingCost = false;

  bool get _isEditing => widget.item != null;

  bool get _asksForCost {
    if (widget.forLot) return false;
    if (_isEditing) return _editingCost;
    return (int.tryParse(_qtyController.text) ?? 0) > 0;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _priceController = TextEditingController(
      text: item != null ? formatAmountInput(item.unitPrice) : '',
    );
    _qtyController = TextEditingController(
      text: item != null ? item.qtyOnHand.toString() : '',
    );
    final cost = item?.unitCost;
    _costController = TextEditingController(text: cost == null ? '' : formatAmountInput(cost));
    _category = item?.category ?? widget.categories.firstOrNull ?? 'Other';
    _onSale = item?.onSale ?? false;
    // A sale from before discounts (the old Bargain tag) opens on a price,
    // left blank to fill in.
    _saleBy = item?.salePercent != null ? _SaleBy.percent : _SaleBy.price;
    final saleValue = item?.salePercent ?? item?.salePrice;
    _saleController = TextEditingController(text: saleValue == null ? '' : formatAmountInput(saleValue));
    _imagePath = item?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _saleController.dispose();
    super.dispose();
  }

  double? get _regularPrice => parseAmount(_priceController.text);
  double? get _saleValue => parseAmount(_saleController.text);

  /// The item as the sale fields describe it, for the live preview.
  Item? get _salePreview {
    final regular = _regularPrice;
    final value = _saleValue;
    if (regular == null || value == null) return null;
    return Item(
      id: '',
      name: '',
      category: '',
      unitPrice: regular,
      qtyOnHand: 0,
      onSale: true,
      salePercent: _saleBy == _SaleBy.percent ? value : null,
      salePrice: _saleBy == _SaleBy.price ? value : null,
    );
  }

  String? _validateSale(String? v) {
    final value = parseAmount(v ?? '');
    if (v == null || v.trim().isEmpty) {
      return _saleBy == _SaleBy.percent ? 'How much off?' : 'What does it sell for on sale?';
    }
    if (_saleBy == _SaleBy.percent) {
      return value == null || value <= 0 || value >= 100 ? 'Between 1 and 99' : null;
    }
    if (value == null || value < 0) return 'Enter a price';
    final regular = _regularPrice;
    if (regular != null && value >= regular) return 'Less than the regular ${_peso.format(regular)}';
    return null;
  }

  Future<void> _pickImage() async {
    final file = await openFile(acceptedTypeGroups: const [_imageTypeGroup]);
    if (file == null || !mounted) return;
    final saved = await ItemImageStorage.instance.save(file);
    if (!mounted) return;
    setState(() => _imagePath = saved);
  }

  void _removeImage() => setState(() => _imagePath = null);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // The old photo is only ever replaced/cleared here, on an actual save —
    // cancelling the dialog leaves the item's stored photo untouched.
    final oldPath = widget.item?.imagePath;
    if (oldPath != null && oldPath != _imagePath) {
      await ItemImageStorage.instance.delete(oldPath);
    }

    final result = Item(
      id: widget.item?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _category,
      unitPrice: parseAmount(_priceController.text)!,
      qtyOnHand: widget.forLot ? 0 : int.parse(_qtyController.text),
      onSale: _onSale,
      salePercent: _onSale && _saleBy == _SaleBy.percent ? _saleValue : null,
      salePrice: _onSale && _saleBy == _SaleBy.price ? _saleValue : null,
      imagePath: _imagePath,
      unitCost: _asksForCost ? parseAmount(_costController.text) : widget.item?.unitCost,
    );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  /// An existing item's cost as plain text. Only pieces on hand can be
  /// costed, so the link to set or fix it shows only while there are some.
  Widget _costLine(BuildContext context, Item item) {
    final cost = item.unitCost;
    if (cost == null && item.qtyOnHand <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              cost == null ? 'No cost yet, so profit on these isn\'t counted.' : 'You paid ${_peso.format(cost)} each.',
              style: context.text.bodySmall,
            ),
          ),
          if (item.qtyOnHand > 0)
            TextButton(
              onPressed: () => setState(() => _editingCost = true),
              child: Text(cost == null ? 'SET COST' : 'CHANGE'),
            ),
        ],
      ),
    );
  }

  /// Percent off or a set price, and what the piece sells for either way.
  Widget _saleFields(BuildContext context) {
    final preview = _salePreview;
    final String? outcome;
    if (preview == null || _validateSale(_saleController.text) != null) {
      outcome = widget.item?.onSale == true && widget.item!.salePercent == null && widget.item!.salePrice == null
          ? 'Tagged SALE with no discount yet — set one, or turn On sale off.'
          : null;
    } else {
      outcome = 'Sells for ${_peso.format(preview.sellingPrice)} instead of ${_peso.format(preview.unitPrice)}'
          '${_saleBy == _SaleBy.price && preview.percentOff != null ? ' — ${preview.percentOff}% off' : ''}.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceStrip<_SaleBy>(
          options: const [(_SaleBy.percent, '% off'), (_SaleBy.price, 'Sale price')],
          selected: _saleBy,
          onSelected: (v) => setState(() {
            _saleBy = v;
            _saleController.clear();
          }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(_saleBy),
          controller: _saleController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _saleBy == _SaleBy.percent ? 'Percent off (%)' : 'Sale price (₱)',
            helperText: outcome,
            helperMaxLines: 2,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          // Re-checked while typing, so a fixed price clears its error and
          // shows the preview straight away.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateSale,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'EDIT ITEM' : widget.forLot ? 'NEW ITEM IN THIS LOT' : 'ADD ITEM'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ItemThumbnail(imagePath: _imagePath, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _pickImage,
                            child: Text(
                              _imagePath == null ? 'ADD PHOTO' : 'CHANGE PHOTO',
                            ),
                          ),
                          if (_imagePath != null)
                            TextButton(
                              onPressed: _removeImage,
                              child: const Text('REMOVE'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                CategoryField(
                  options: widget.categories,
                  value: _category,
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Sells for (₱)'),
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = parseAmount(v);
                    if (n == null || n < 0) return 'Enter a valid price';
                    return null;
                  },
                ),
                if (!widget.forLot) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _qtyController,
                    enabled: !_isEditing,
                    decoration: InputDecoration(
                      labelText: _isEditing ? 'In stock' : 'Already in stock',
                      helperText: _isEditing
                          ? 'Change with Receive stock or Adjust stock.'
                          : 'Buying new stock? Use Receive stock so its cost is counted.',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 0) return 'Enter a valid qty';
                      return null;
                    },
                  ),
                ],
                if (_isEditing && !_editingCost) _costLine(context, widget.item!),
                if (_asksForCost) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _costController,
                    autofocus: _isEditing,
                    decoration: const InputDecoration(
                      labelText: 'What you paid for each (₱)',
                      helperText: 'Optional. Without it, profit on these isn\'t counted.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = parseAmount(v);
                      if (n == null || n < 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 4),
                SwitchListTile(
                  value: _onSale,
                  onChanged: (v) => setState(() => _onSale = v),
                  title: const Text('On sale'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_onSale) _saleFields(context),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'SAVE' : widget.forLot ? 'ADD TO LOT' : 'ADD'),
        ),
      ],
    );
  }
}
