import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A form-styled date picker field for recording when something happened —
/// defaults to allowing any past date up to today, since the books record
/// events, not plans.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value.isAfter(now) ? now : value,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    // Keep the original time of day so same-day entries stay in order.
    onChanged(DateTime(picked.year, picked.month, picked.day, value.hour, value.minute, value.second));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(CupertinoIcons.calendar, size: 18),
        ),
        child: Text(DateFormat('MMM d, y').format(value)),
      ),
    );
  }
}
