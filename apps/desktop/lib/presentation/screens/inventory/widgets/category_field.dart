import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/constants/categories.dart';

/// Category dropdown with a "New category…" choice at the bottom, so a
/// piece that fits none of the list (long sleeves out of a mixed bundle)
/// never has to be filed under the wrong one. A new category shows up here
/// right away; the caller saves it to the shop's list along with the item.
class CategoryField extends StatefulWidget {
  const CategoryField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label = 'Category',
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<CategoryField> {
  static const _newCategory = '\u0000new';

  /// Bumped when "New category…" is cancelled, to reset the dropdown's own
  /// selection back to [CategoryField.value].
  int _version = 0;

  List<String> get _options => [
        ...widget.options,
        if (findCategory(widget.options, widget.value) == null) widget.value,
      ];

  Future<void> _onChanged(String? v) async {
    if (v == null) return;
    if (v != _newCategory) return widget.onChanged(v);
    final created = await showDialog<String>(
      context: context,
      builder: (_) => NewCategoryDialog(existing: _options),
    );
    if (!mounted) return;
    if (created == null) {
      setState(() => _version++);
    } else {
      widget.onChanged(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('${widget.value}#$_version'),
      initialValue: widget.value,
      isExpanded: true,
      decoration: InputDecoration(labelText: widget.label),
      items: [
        for (final c in _options) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(
          value: _newCategory,
          child: Row(
            children: [
              Icon(CupertinoIcons.add, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'New category…',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: _onChanged,
    );
  }
}

/// Asks for a category name. Returns the existing spelling when it's
/// already on [existing] (ignoring case), so "long sleeves" never becomes a
/// second "Long Sleeves".
class NewCategoryDialog extends StatefulWidget {
  const NewCategoryDialog({super.key, required this.existing});
  final List<String> existing;

  @override
  State<NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<NewCategoryDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _controller.text.trim();
    Navigator.of(context).pop(findCategory(widget.existing, name) ?? name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Category'),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Long Sleeves, Dress, Jacket'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
