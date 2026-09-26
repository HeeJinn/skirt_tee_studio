import 'dart:io';

import 'package:flutter/material.dart';

import 'package:shop_core/core/theme/app_theme.dart';

/// An item photo, or — when there isn't one (or the file is gone) — a
/// serif monogram of the item's name on a tonal tile. A grid of generic
/// "image" icons reads as broken images; initials read as intentional and
/// still help staff tell items apart.
///
/// Pass [size] for a fixed square, or leave it null to fill the parent.
class ItemThumbnail extends StatelessWidget {
  const ItemThumbnail({
    super.key,
    required this.imagePath,
    this.name,
    this.size,
    this.radius = AppRadius.control,
  });

  final String? imagePath;
  final String? name;
  final double? size;
  final double radius;

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    Widget fallback(double extent) {
      final initials = name == null ? '' : initialsOf(name!);
      if (initials.isEmpty) {
        return Icon(Icons.image_outlined, size: extent * 0.4, color: tokens.mutedText);
      }
      // A quiet placeholder, not a headline — sized down and softened so a
      // grid of them doesn't out-shout the item names and prices.
      return Text(
        initials,
        style: TextStyle(
          fontFamily: kSerifFont,
          fontWeight: FontWeight.w700,
          fontSize: (extent * 0.26).clamp(10.0, 38.0),
          letterSpacing: 1.5,
          color: tokens.mutedText.withValues(alpha: 0.55),
        ),
      );
    }

    final tile = LayoutBuilder(
      builder: (context, constraints) {
        final extent = constraints.biggest.shortestSide.isFinite ? constraints.biggest.shortestSide : 40.0;
        final path = imagePath;
        return Container(
          color: tokens.sunken,
          alignment: Alignment.center,
          child: path == null
              ? fallback(extent)
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => fallback(extent),
                ),
        );
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: size == null ? tile : SizedBox.square(dimension: size, child: tile),
    );
  }
}
