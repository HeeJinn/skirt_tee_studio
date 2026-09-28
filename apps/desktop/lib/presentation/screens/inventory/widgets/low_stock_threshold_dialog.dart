import 'package:flutter/material.dart';

/// Lets staff tune the store-wide "LOW STOCK" cutoff (POS + Inventory both
/// read it). Returns the new threshold via Navigator.pop, or null if
/// cancelled.
class LowStockThresholdDialog extends StatefulWidget {
  const LowStockThresholdDialog({super.key, required this.currentThreshold});
  final int currentThreshold;

  @override
  State<LowStockThresholdDialog> createState() => _LowStockThresholdDialogState();
}

class _LowStockThresholdDialogState extends State<LowStockThresholdDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentThreshold}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(int.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Low Stock Threshold'),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Flag items at or below',
              helperText: 'Applies store-wide, on both POS and Inventory.',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 0) return 'Enter a whole number, 0 or more';
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
