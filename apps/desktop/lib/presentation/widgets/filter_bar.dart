import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged, this.width = 280});

  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 20),
          hintText: hint,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Single-select chips on one horizontally-scrolling line — never wraps into
/// a second row, so the filter bar keeps a fixed height.
class ChoiceStrip<T> extends StatelessWidget {
  const ChoiceStrip({super.key, required this.options, required this.selected, required this.onSelected});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(label),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
            ),
        ],
      ),
    );
  }
}
