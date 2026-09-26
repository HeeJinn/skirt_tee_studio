import 'package:flutter/cupertino.dart';

/// "THE SKIRT & TEE / STUDIO", spaced out the way the desktop sidebar and
/// the shop's logo set it.
class ShopWordmark extends StatelessWidget {
  const ShopWordmark({super.key, this.scale = 1, this.alignment = CrossAxisAlignment.center});

  final double scale;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoTheme.of(context).textTheme.textStyle.color;
    final muted = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          'THE SKIRT & TEE',
          style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w700, letterSpacing: 3 * scale, color: ink),
        ),
        SizedBox(height: 4 * scale),
        Text(
          'STUDIO',
          style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w500, letterSpacing: 6 * scale, color: muted),
        ),
      ],
    );
  }
}
