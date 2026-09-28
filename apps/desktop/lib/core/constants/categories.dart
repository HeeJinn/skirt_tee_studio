import 'package:shop_core/domain/entities/item.dart';

/// Item categories are the owners' own list (SettingsViewModel.categories),
/// synced across the shop's devices. "Sale" is a markdown on Item, not a
/// category — see Item.onSale.
///
/// Every category to offer: the saved list first, then any an item still
/// carries that isn't on it (removed since, or typed on another device), so
/// no item ever drops out of a filter.
List<String> categoryOptions(List<String> saved, Iterable<Item> items) {
  final options = [...saved];
  for (final item in items) {
    if (findCategory(options, item.category) == null) options.add(item.category);
  }
  return options;
}

/// [name] as it's already spelled in [categories], ignoring case and
/// surrounding spaces — so "long sleeves " finds "Long Sleeves". Null when
/// it's new.
String? findCategory(Iterable<String> categories, String name) {
  final key = name.trim().toLowerCase();
  for (final c in categories) {
    if (c.trim().toLowerCase() == key) return c;
  }
  return null;
}
