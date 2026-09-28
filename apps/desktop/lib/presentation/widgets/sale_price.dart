import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'status_pill.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// The Sale tag, with how much is off when the sale sets a discount
/// ("Sale −20%"). Items tagged before sales had discounts just say Sale.
class SalePill extends StatelessWidget {
  const SalePill({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final off = item.percentOff;
    return StatusPill(label: off == null ? 'Sale' : 'Sale −$off%', tone: PillTone.accent);
  }
}

/// What the item sells for now, with the regular price struck through
/// beside it while it's marked down.
class SalePriceText extends StatelessWidget {
  const SalePriceText({super.key, required this.item, this.style, this.suffix = ''});

  final Item item;
  final TextStyle? style;

  /// Appended to the price, e.g. " each".
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? context.text.bodyMedium)?.copyWith(fontFeatures: kTabularFigures);
    if (!item.isMarkedDown) return Text('${_peso.format(item.unitPrice)}$suffix', style: base);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${_peso.format(item.sellingPrice)}$suffix', style: TextStyle(color: context.tokens.accent)),
          const TextSpan(text: '  '),
          TextSpan(
            text: _peso.format(item.unitPrice),
            style: context.text.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              fontWeight: FontWeight.w400,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
      style: base,
      semanticsLabel: 'On sale for ${_peso.format(item.sellingPrice)}, was ${_peso.format(item.unitPrice)}',
    );
  }
}
