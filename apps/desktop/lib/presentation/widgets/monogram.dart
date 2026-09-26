import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'item_thumbnail.dart';

/// Initials in a sage circle — a recognizable mark for a person.
class Monogram extends StatelessWidget {
  const Monogram({super.key, required this.name, this.radius = 18, this.onSage = false});

  final String name;
  final double radius;

  /// On the sage sidebar a sage circle vanishes — flip to the surface color.
  final bool onSage;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: onSage ? context.colors.surface : context.colors.primaryContainer,
      child: Text(
        ItemThumbnail.initialsOf(name),
        style: TextStyle(
          fontFamily: kSerifFont,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
          color: context.colors.onSurface,
        ),
      ),
    );
  }
}
