import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// A search field in iOS's shape: a capsule of quiet fill with the
/// magnifier inside, and a clear button once there's text.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width = 280,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capsule = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          prefixIcon: const Icon(CupertinoIcons.search, size: 18),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 36,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 17),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                ),
          hintText: widget.hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          border: capsule,
          enabledBorder: capsule,
          focusedBorder: capsule.copyWith(
            borderSide: BorderSide(
              color: context.colors.primary.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
        ),
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
      ),
    );
  }
}

/// A segmented control in iOS 26's shape, for switching between a few
/// views of the same thing (a period, a status): a capsule track of quiet
/// fill, the chosen segment raised on a capsule thumb, and no dividers.
/// Segments size to their labels, so it sits inline in a toolbar row.
class SegmentedStrip<T> extends StatelessWidget {
  const SegmentedStrip({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final thumb = dark ? const Color(0xFF636366) : Colors.white;
    // Keeps its own width even when a parent stretches it.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      // Scrolls sideways rather than overflowing in a narrow window.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            color: context.tokens.sunken,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in options)
                Semantics(
                  button: true,
                  selected: value == selected,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (value != selected) onSelected(value);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: ShapeDecoration(
                          color: value == selected
                              ? thumb
                              : thumb.withValues(alpha: 0),
                          shape: const StadiumBorder(),
                          shadows: [
                            if (value == selected && !dark)
                              const BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Text(
                          label,
                          style: context.text.bodyMedium?.copyWith(
                            fontWeight: value == selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-select capsules on one horizontally-scrolling line, as iOS 26
/// filters a list by many values (categories, people) — never wraps into a
/// second row, so the filter bar keeps a fixed height.
class ChoiceStrip<T> extends StatelessWidget {
  const ChoiceStrip({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

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
