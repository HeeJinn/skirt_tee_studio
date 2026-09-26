import 'dart:io';

import 'package:flutter/cupertino.dart';

/// An item's photo, filling its box. Items without one — or whose photo
/// hasn't finished downloading from the cloud — show the item's initials.
class ItemPhoto extends StatelessWidget {
  const ItemPhoto({super.key, required this.imagePath, required this.name});

  final String? imagePath;
  final String name;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final placeholder = _Initials(name: name);
    return ColoredBox(
      color: CupertinoColors.systemGrey5.resolveFrom(context),
      child: path == null
          ? placeholder
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: CupertinoColors.systemGrey.resolveFrom(context),
        ),
      ),
    );
  }
}
