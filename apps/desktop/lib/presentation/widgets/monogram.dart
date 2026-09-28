import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'item_thumbnail.dart';

/// Initials in a soft circle of the accent, like a Contacts monogram — a
/// recognizable mark for a person.
class Monogram extends StatelessWidget {
  const Monogram({super.key, required this.name, this.radius = 18, this.onSage = false});

  final String name;
  final double radius;

  /// Kept for callers that still pass it; the wash reads on every surface.
  final bool onSage;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.primaryContainer,
      child: Text(
        ItemThumbnail.initialsOf(name),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
          color: context.colors.onSurface,
        ),
      ),
    );
  }
}
