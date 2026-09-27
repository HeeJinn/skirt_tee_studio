import 'package:flutter/cupertino.dart';

import '../../../core/theme/shop_ui.dart';
import 'line_art.dart';

/// What a screen shows before the shop has recorded anything for it: a
/// line drawing over a short note, centered like iOS's own empty screens.
/// Filtered or past-period empties stay plain text; this is for "nothing
/// yet".
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.drawing, required this.message});

  final LineArtDrawing drawing;
  final String message;

  @override
  Widget build(BuildContext context) {
    // Centered in what's visible: above the tab bar, not behind it.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LineArt(drawing, height: 96),
                const SizedBox(height: Space.lg),
                Text(message, textAlign: TextAlign.center, style: ShopType.subhead(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
