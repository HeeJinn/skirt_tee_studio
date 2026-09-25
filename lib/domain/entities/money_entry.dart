/// What kind of money movement a [MoneyEntry] records. Stock purchases are
/// deliberately not here — buying a lot turns cash into stock, it isn't a
/// cost until the pieces sell or are written off (see StockLot).
enum MoneyEntryKind {
  /// The owners putting their own money into the shop.
  capitalIn('Money put in'),

  /// A cost of running the shop — reduces profit.
  expense('Expense'),

  /// The owners taking money home, including paying themselves. Not an
  /// expense: it doesn't change what the shop earned, only where it went.
  ownerDraw('Taken home');

  const MoneyEntryKind(this.label);
  final String label;
}

enum ExpenseCategory {
  rent('Rent'),
  utilities('Utilities'),
  wages('Staff wages'),
  marketing('Ads & marketing'),
  packaging('Packaging'),
  delivery('Delivery & shipping'),
  supplies('Store supplies'),
  repairs('Repairs & equipment'),
  fees('Bank & e-wallet fees'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;
}

/// Whose money paid for an expense or a stock lot. Anything paid from the
/// owners' own pockets counts as money they put into the shop, so it's
/// included in the payback total without a second entry.
enum PaidFrom {
  shop('Shop money'),
  owners('Our own money');

  const PaidFrom(this.label);
  final String label;
}

/// One line in the owners' money log.
class MoneyEntry {
  const MoneyEntry({
    required this.id,
    required this.at,
    required this.kind,
    required this.amount,
    this.category,
    this.paidFrom = PaidFrom.shop,
    this.person,
    this.note = '',
  });

  final String id;
  final DateTime at;
  final MoneyEntryKind kind;

  /// Always positive; [kind] says which way the money moved.
  final double amount;

  /// Set for expenses only.
  final ExpenseCategory? category;

  /// Meaningful for expenses only — money put in is by definition the
  /// owners' and money taken home by definition the shop's.
  final PaidFrom paidFrom;

  /// Which owner put the money in or took it home (the shop is run by a
  /// couple). Null means both / not specified.
  final String? person;
  final String note;

  /// Whether this entry adds to what the owners have invested.
  bool get isOwnersMoneyIn =>
      kind == MoneyEntryKind.capitalIn || (kind == MoneyEntryKind.expense && paidFrom == PaidFrom.owners);
}
