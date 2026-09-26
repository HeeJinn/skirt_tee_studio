import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/reservation.dart';

/// Add/Edit Reservation dialog. Pass an existing [reservation] to edit it in
/// place (preserving its id and status); omit it to create a new one.
/// Requires at least one Item in inventory to pick from (a reservation
/// always points at a specific item).
class ReservationFormDialog extends StatefulWidget {
  const ReservationFormDialog({super.key, required this.items, this.reservation});
  final List<Item> items;
  final Reservation? reservation;

  @override
  State<ReservationFormDialog> createState() => _ReservationFormDialogState();
}

class _ReservationFormDialogState extends State<ReservationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late Item? _selectedItem;
  late DateTime _pickupDate;

  bool get _isEditing => widget.reservation != null;

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    _nameController = TextEditingController(text: reservation?.customerName ?? '');
    _contactController = TextEditingController(text: reservation?.contact ?? '');
    _selectedItem = widget.items.isEmpty
        ? null
        : widget.items.firstWhere(
            (item) => item.id == reservation?.itemId,
            orElse: () => widget.items.first,
          );
    _pickupDate = reservation?.pickupDate ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _pickupDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selectedItem == null) return;
    final result = Reservation(
      id: widget.reservation?.id ?? const Uuid().v4(),
      customerName: _nameController.text.trim(),
      contact: _contactController.text.trim(),
      itemId: _selectedItem!.id,
      itemName: _selectedItem!.name,
      pickupDate: _pickupDate,
      status: widget.reservation?.status ?? ReservationStatus.pending,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return AlertDialog(
        title: const Text('ADD RESERVATION'),
        content: const Text('Add an item to inventory first before logging a reservation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(_isEditing ? 'EDIT RESERVATION' : 'ADD RESERVATION'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Customer name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact (phone/FB)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Item>(
                initialValue: _selectedItem,
                decoration: const InputDecoration(labelText: 'Item'),
                items: widget.items
                    .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedItem = v),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pickup: ${_pickupDate.month}/${_pickupDate.day}/${_pickupDate.year}'),
                  TextButton(onPressed: _pickDate, child: const Text('CHANGE')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(onPressed: _submit, child: Text(_isEditing ? 'SAVE' : 'ADD')),
      ],
    );
  }
}
