import 'package:flutter/cupertino.dart';

/// "THE SKIRT & TEE / STUDIO", spaced out the way the desktop sidebar and
/// the shop's logo set it.
class ShopWordmark extends StatelessWidget {
  const ShopWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoTheme.of(context).textTheme.textStyle.color;
    final muted = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      children: [
        Text(
          'THE SKIRT & TEE',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 3, color: ink),
        ),
        const SizedBox(height: 4),
        Text(
          'STUDIO',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 6, color: muted),
        ),
      ],
    );
  }
}
