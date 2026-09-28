import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import '../../../../core/constants/categories.dart';
import '../../../widgets/list_surface.dart';

/// The shop's item categories: add new ones, remove ones nothing uses.
/// A category still on an item can't be removed — the item would be left
/// filed under nothing. Returns the new list via Navigator.pop, or null if
/// cancelled.
class CategoriesDialog extends StatefulWidget {
  const CategoriesDialog({super.key, required this.categories, required this.itemCounts});

  final List<String> categories;

  /// How many items are filed under each category.
  final Map<String, int> itemCounts;

  @override
  State<CategoriesDialog> createState() => _CategoriesDialogState();
}

class _CategoriesDialogState extends State<CategoriesDialog> {
  late final List<String> _categories = [...widget.categories];
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final existing = findCategory(_categories, name);
    setState(() {
      if (existing != null) {
        _error = '"$existing" is already on the list.';
      } else {
        _categories.add(name);
        _controller.clear();
        _error = null;
      }
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('CATEGORIES'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Shown on POS and Inventory, and when adding items. Categories still used by an item can\'t be removed.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: ListSurface(
                  children: [
                    for (final c in _categories)
                      _CategoryRow(
                        name: c,
                        count: widget.itemCounts[c] ?? 0,
                        onRemove: () => setState(() => _categories.remove(c)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(hintText: 'New category, e.g. Dress', errorText: _error),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(onPressed: _add, child: const Text('ADD')),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(_categories), child: const Text('SAVE')),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.name, required this.count, required this.onRemove});

  final String name;
  final int count;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(name, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Text(count == 0 ? 'no items' : '$count ${count == 1 ? 'item' : 'items'}', style: context.text.bodySmall),
          if (count == 0)
            IconButton(icon: const Icon(Icons.close, size: 16), tooltip: 'Remove', onPressed: onRemove)
          else
            const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}
