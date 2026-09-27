import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/utils/money_input.dart';
import 'package:shop_core/data/datasources/local/item_image_storage.dart';
import 'package:shop_core/domain/entities/item.dart';
import '../../../widgets/item_thumbnail.dart';

const _imageTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: ['jpg', 'jpeg', 'png', 'webp'],
);

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

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
  const ItemFormDialog({super.key, this.item, this.forLot = false});
  final Item? item;

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
  late String _category;
  late bool _isBargain;
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
      text: item != null ? item.unitPrice.toString() : '',
    );
    _qtyController = TextEditingController(
      text: item != null ? item.qtyOnHand.toString() : '',
    );
    final cost = item?.unitCost;
    _costController = TextEditingController(text: cost == null ? '' : formatAmountInput(cost));
    _category = item?.category ?? kCategories.first;
    _isBargain = item?.isBargain ?? false;
    _imagePath = item?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
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
      unitPrice: double.parse(_priceController.text),
      qtyOnHand: widget.forLot ? 0 : int.parse(_qtyController.text),
      isBargain: _isBargain,
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
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: kCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Sells for (₱)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
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
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _isBargain,
                  onChanged: (v) => setState(() => _isBargain = v ?? false),
                  title: const Text('Bargain tier'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
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
