import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/staff.dart';
import 'package:shop_core/domain/entities/stock.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/money_view_model.dart';
import '../../viewmodels/sales_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_pill.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/calculations/money_calculations.dart';
import 'widgets/money_entry_dialog.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'widgets/profit_breakdown.dart';
import 'widgets/sales_vs_costs_chart.dart';

final _day = DateFormat('MMM d, y');

/// Owner-only: how much has gone into the shop, how much it has earned
/// back, and where the money went. Answers the question the owners
/// couldn't — "how much did we put in, and how much came back?"
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

enum _LogFilter {
  all('All', ''),
  capitalIn('Put in', 'PUT IN'),
  expense('Expenses', 'EXPENSE'),
  ownerDraw('Taken home', 'TAKEN HOME'),
  stock('Stock bought', 'STOCK');

  const _LogFilter(this.label, this.pill);

  /// The filter chip.
  final String label;

  /// The tag on one row of this kind.
  final String pill;
}

class _MoneyScreenState extends State<MoneyScreen> {
  ReportRange _range = ReportRange.last30Days;
  _LogFilter _logFilter = _LogFilter.all;

  @override
  void initState() {
    super.initState();
    // Lots and losses are recorded from Inventory; pick them up on arrival.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MoneyViewModel>().load();
    });
  }

  List<String> get _ownerNames => context
      .read<SessionViewModel>()
      .staff
      .where((s) => s.role == StaffRole.owner)
      .map((s) => s.name)
      .toList();

  Future<void> _record(MoneyEntryKind kind) async {
    final entry = await showDialog<MoneyEntry>(
      context: context,
      builder: (_) => MoneyEntryDialog(kind: kind, ownerNames: _ownerNames),
    );
    if (entry == null || !mounted) return;
    await context.read<MoneyViewModel>().addEntry(entry);
    if (!mounted) return;
    await context.read<SessionViewModel>().log('Recorded ${_describe(entry)}');
  }

  Future<void> _edit(MoneyEntry original) async {
    final entry = await showDialog<MoneyEntry>(
      context: context,
      builder: (_) => MoneyEntryDialog(kind: original.kind, ownerNames: _ownerNames, entry: original),
    );
    if (entry == null || !mounted) return;
    await context.read<MoneyViewModel>().updateEntry(entry);
    if (!mounted) return;
    await context.read<SessionViewModel>().log('Edited ${_describe(original)} → ${peso.format(entry.amount)}');
  }

  Future<void> _confirmDelete(MoneyEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('DELETE ENTRY'),
        content: Text('Delete ${_describe(entry)} from ${_day.format(entry.at)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dialogContext.tokens.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MoneyViewModel>().deleteEntry(entry.id);
    if (!mounted) return;
    await context.read<SessionViewModel>().log('Deleted ${_describe(entry)} from ${_day.format(entry.at)}');
  }

  static String _describe(MoneyEntry e) => switch (e.kind) {
        MoneyEntryKind.capitalIn => 'money put in ${peso.format(e.amount)}',
        MoneyEntryKind.expense => 'expense ${peso.format(e.amount)} · ${(e.category ?? ExpenseCategory.other).label}',
        MoneyEntryKind.ownerDraw => 'taken home ${peso.format(e.amount)}',
      };

  @override
  Widget build(BuildContext context) {
    final money = context.watch<MoneyViewModel>();
    final sales = context.watch<SalesViewModel>().sales;
    final items = context.watch<InventoryViewModel>().items;
    final now = DateTime.now();
    final booksStart = money.booksStartedAt ?? now;
    final rangeStart = _range.startDate(now);
    final since = rangeStart == null || rangeStart.isBefore(booksStart) ? booksStart : rangeStart;

    final statement = profitStatement(
      sales: sales,
      entries: money.entries,
      movements: money.movements,
      since: since,
    );
    final pay = payback(
      sales: sales,
      entries: money.entries,
      movements: money.movements,
      lots: money.lots,
      booksStartedAt: booksStart,
    );
    final months = monthlyProfit(
      sales: sales,
      entries: money.entries,
      movements: money.movements,
      booksStartedAt: booksStart,
      now: now,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Money',
            subtitle: 'Books started ${_day.format(booksStart)} · every figure counts from then',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _record(MoneyEntryKind.capitalIn),
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: const Text('PUT MONEY IN'),
              ),
              OutlinedButton.icon(
                onPressed: () => _record(MoneyEntryKind.ownerDraw),
                icon: const Icon(Icons.north_east, size: 18),
                label: const Text('TAKE HOME'),
              ),
              ElevatedButton.icon(
                onPressed: () => _record(MoneyEntryKind.expense),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('RECORD EXPENSE'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final left = _MoneyLeftPanel(
                        money: shopMoney(
                          sales: sales,
                          entries: money.entries,
                          lots: money.lots,
                          booksStartedAt: booksStart,
                        ),
                        stockValue: stockValueAtCost(items),
                        booksStart: booksStart,
                      );
                      final paid = _PaybackPanel(payback: pay, onPutIn: () => _record(MoneyEntryKind.capitalIn));
                      if (constraints.maxWidth < 900) {
                        return Column(children: [left, const SizedBox(height: AppSpacing.lg), paid]);
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(child: paid),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ChoiceStrip<ReportRange>(
                    options: [
                      for (final r in ReportRange.values)
                        if (r != ReportRange.today) (r, r == ReportRange.allTime ? 'SINCE BOOKS STARTED' : r.label),
                    ],
                    selected: _range,
                    onSelected: (r) => setState(() => _range = r),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ProfitStats(statement: statement),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final breakdown = _Card(
                        title: 'PROFIT BREAKDOWN',
                        caption: _range == ReportRange.allTime
                            ? 'Since the books started'
                            : '${_range.description}, from ${_day.format(since)}',
                        child: ProfitBreakdown(statement: statement),
                      );
                      final chart = _Card(
                        title: 'SALES VS COSTS',
                        caption: 'By month · costs are what sold, expenses, and losses',
                        child: SalesVsCostsChart(months: months),
                      );
                      if (constraints.maxWidth < 900) {
                        return Column(children: [breakdown, const SizedBox(height: AppSpacing.lg), chart]);
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: breakdown),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(child: chart),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MoneyLog(
                    rows: _logRows(money),
                    filter: _logFilter,
                    onFilter: (f) => setState(() => _logFilter = f),
                    onEdit: _edit,
                    onDelete: _confirmDelete,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_LogRow> _logRows(MoneyViewModel money) {
    final piecesByLot = <String, int>{};
    for (final m in money.movements.where((m) => m.lotId != null)) {
      piecesByLot.update(m.lotId!, (v) => v + m.qty, ifAbsent: () => m.qty);
    }
    final rows = [
      for (final e in money.entries) _LogRow.entry(e),
      for (final lot in money.lots) _LogRow.lot(lot, piecesByLot[lot.id] ?? 0),
    ];
    return rows..sort((a, b) => b.at.compareTo(a.at));
  }
}

/// How much money the shop is holding right now, and how it got there:
/// everything that came in, less everything that went out.
class _MoneyLeftPanel extends StatelessWidget {
  const _MoneyLeftPanel({required this.money, required this.stockValue, required this.booksStart});

  final ShopMoney money;
  final double stockValue;
  final DateTime booksStart;

  @override
  Widget build(BuildContext context) {
    final m = money;
    final nonCash = m.sales - m.cashSales;
    final below = m.left < 0;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('MONEY IN THE SHOP', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            signedPeso(m.left, whole: true),
            style: context.text.displaySmall?.copyWith(
              fontFeatures: kTabularFigures,
              color: below ? context.tokens.danger : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            below
                ? 'More went out than the books show coming in. Money you put in that wasn\'t recorded '
                    'is the usual reason — add it with Put money in.'
                : 'Cash and e-wallets together, from everything recorded since ${_day.format(booksStart)}.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FlowLine('Put in by the owners', '+${pesoWhole.format(m.putIn)}'),
          _FlowLine(
            'Sales',
            '+${pesoWhole.format(m.sales)}',
            detail: nonCash > 0 ? '${pesoWhole.format(m.cashSales)} cash · ${pesoWhole.format(nonCash)} GCash, Maya & card' : null,
          ),
          _FlowLine('Expenses paid from the shop', _minus(m.expenses)),
          _FlowLine('Stock bought with shop money', _minus(m.stockBought)),
          _FlowLine('Taken home', _minus(m.takenHome)),
          const Divider(height: AppSpacing.lg),
          _FlowLine('Money left', signedPeso(m.left, whole: true), strong: true),
          _FlowLine('Also on the rack: stock, at what it cost', pesoWhole.format(stockValue), muted: true),
        ],
      ),
    );
  }

  static String _minus(double v) => v == 0 ? pesoWhole.format(0) : '−${pesoWhole.format(v)}';
}

/// One step of the money-left sum: label on the left, amount on the right.
class _FlowLine extends StatelessWidget {
  const _FlowLine(this.label, this.value, {this.detail, this.strong = false, this.muted = false});

  final String label;
  final String value;
  final String? detail;
  final bool strong;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final base = strong ? context.text.titleMedium : context.text.bodyMedium;
    final color = muted ? context.tokens.mutedText : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: base?.copyWith(color: color)),
                if (detail != null) Text(detail!, style: context.text.bodySmall?.copyWith(fontFeatures: kTabularFigures)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            style: base?.copyWith(
              color: color,
              fontFeatures: kTabularFigures,
              fontWeight: strong ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.container),
        border: Border.all(color: context.tokens.hairline),
      ),
      child: child,
    );
  }
}

/// All-time: what the owners put in against what the shop has earned.
class _PaybackPanel extends StatelessWidget {
  const _PaybackPanel({required this.payback, required this.onPutIn});

  final Payback payback;
  final VoidCallback onPutIn;

  @override
  Widget build(BuildContext context) {
    final p = payback;
    final share = p.recoveredShare;

    final Widget headline;
    final String sentence;
    if (share == null) {
      headline = Text('Nothing put in yet', style: context.text.headlineMedium);
      sentence = 'Record the money you\'ve put into the shop — startup cash, racks, anything you paid for yourselves — '
          'and this tracks how much of it the shop has earned back.';
    } else {
      headline = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Behind (negative) reads as 0% — the sentence gives the shortfall.
          Text('${(share * 100).clamp(0, 999).round()}%', style: context.text.displaySmall),
          const SizedBox(width: AppSpacing.sm),
          Text('earned back', style: context.text.titleMedium),
        ],
      );
      sentence = p.earned < 0
          ? 'The shop is ${pesoWhole.format(-p.earned)} behind so far — costs are ahead of sales. '
              'You\'ve put in ${pesoWhole.format(p.invested)}.'
          : p.remainingToRecover == 0
              ? 'Paid back. The shop has earned ${pesoWhole.format(p.earned)} on the '
                  '${pesoWhole.format(p.invested)} you put in.'
              : 'The shop has earned ${pesoWhole.format(p.earned)} of the ${pesoWhole.format(p.invested)} you\'ve '
                  'put in — ${pesoWhole.format(p.remainingToRecover)} to go.';
    }

    final byPerson = p.investedByPerson.entries.toList();
    final showPeople = byPerson.length > 1 || (byPerson.length == 1 && byPerson.single.key != Payback.bothOwners);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAYBACK', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.md),
          headline,
          const SizedBox(height: AppSpacing.sm),
          Text(sentence, style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          if (share == null)
            OutlinedButton.icon(
              onPressed: onPutIn,
              icon: const Icon(Icons.savings_outlined, size: 18),
              label: const Text('PUT MONEY IN'),
            )
          else
            _Meter(share: share),
          const SizedBox(height: AppSpacing.lg),
          _Fact('Put in, all told', pesoWhole.format(p.invested)),
          if (showPeople)
            for (final MapEntry(key: person, value: amount) in byPerson)
              _Fact(person == Payback.bothOwners ? 'by both' : 'by $person', pesoWhole.format(amount), indent: true),
          _Fact('Earned by the shop', signedPeso(p.earned, whole: true)),
          const SizedBox(height: AppSpacing.md),
          Text(
            '"Put in" also counts expenses and stock you paid for from your own pockets.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Progress toward paying back the investment. Grows in on first show.
class _Meter extends StatelessWidget {
  const _Meter({required this.share});
  final double share;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${(share * 100).round()} percent earned back',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: context.tokens.hairline),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: ColoredBox(color: context.tokens.chartSeries),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.indent = false});
  final String label;
  final String value;

  /// A part of the line above.
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? AppSpacing.lg : 0, indent ? 0 : 6, 0, indent ? 2 : 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodySmall)),
          Text(
            value,
            style: (indent ? context.text.bodySmall : context.text.titleMedium)
                ?.copyWith(fontFeatures: kTabularFigures),
          ),
        ],
      ),
    );
  }
}

class _ProfitStats extends StatelessWidget {
  const _ProfitStats({required this.statement});
  final ProfitStatement statement;

  @override
  Widget build(BuildContext context) {
    final s = statement;
    final topExpense = s.expensesByCategory.keys.firstOrNull;
    return StatRow(
      tiles: [
        StatTile(label: 'Sales', value: pesoWhole.format(s.revenue)),
        StatTile(
          label: 'Gross profit',
          value: signedPeso(s.grossProfit, whole: true),
          caption: s.revenue == 0 ? null : '${(s.grossMargin * 100).round()}% of sales',
        ),
        StatTile(
          label: 'Expenses',
          value: pesoWhole.format(s.totalExpenses),
          caption: topExpense == null ? null : 'Most on ${topExpense.label.toLowerCase()}',
        ),
        StatTile(
          label: s.netProfit < 0 ? 'Net loss' : 'Net profit',
          value: signedPeso(s.netProfit, whole: true),
          caption: s.stockLosses > 0 ? 'After ${pesoWhole.format(s.stockLosses)} stock losses' : null,
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.caption, required this.child});

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.container),
        border: Border.all(color: context.tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.text.titleSmall),
          const SizedBox(height: 2),
          Text(caption, style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// One line of the money log: an entry the owners recorded here, or a lot
/// received in Inventory (shown for the full picture, edited there).
class _LogRow {
  _LogRow.entry(MoneyEntry this.entry)
      : lot = null,
        at = entry.at,
        filter = switch (entry.kind) {
          MoneyEntryKind.capitalIn => _LogFilter.capitalIn,
          MoneyEntryKind.expense => _LogFilter.expense,
          MoneyEntryKind.ownerDraw => _LogFilter.ownerDraw,
        },
        amount = entry.amount,
        title = switch (entry.kind) {
          MoneyEntryKind.capitalIn => 'Money put in',
          MoneyEntryKind.expense => (entry.category ?? ExpenseCategory.other).label,
          MoneyEntryKind.ownerDraw => 'Taken home',
        },
        detail = [
          if (entry.kind == MoneyEntryKind.expense)
            entry.paidFrom == PaidFrom.owners ? 'Paid with ${_whose(entry.person)} own money' : 'Shop money'
          else
            entry.person ?? 'Both owners',
          if (entry.note.isNotEmpty) entry.note,
        ].join(' · ');

  _LogRow.lot(StockLot this.lot, int pieces)
      : entry = null,
        at = lot.at,
        filter = _LogFilter.stock,
        amount = lot.totalCost,
        title = lot.supplier.isEmpty ? 'Stock bought' : 'Stock · ${lot.supplier}',
        detail = [
          '$pieces pieces',
          if (lot.fees > 0) 'incl. ${peso.format(lot.fees)} fees',
          lot.paidFrom == PaidFrom.owners ? 'Paid with ${_whose(lot.person)} own money' : 'Shop money',
          if (lot.note.isNotEmpty) lot.note,
        ].join(' · ');

  final MoneyEntry? entry;
  final StockLot? lot;
  final DateTime at;
  final _LogFilter filter;
  final double amount;
  final String title;
  final String detail;

  static String _whose(String? person) => person == null ? 'our' : '$person\'s';
}

class _MoneyLog extends StatelessWidget {
  const _MoneyLog({
    required this.rows,
    required this.filter,
    required this.onFilter,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_LogRow> rows;
  final _LogFilter filter;
  final ValueChanged<_LogFilter> onFilter;
  final ValueChanged<MoneyEntry> onEdit;
  final ValueChanged<MoneyEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final shown = filter == _LogFilter.all ? rows : rows.where((r) => r.filter == filter).toList();
    final total = shown.fold(0.0, (sum, r) => sum + r.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Money log',
          trailing: filter == _LogFilter.all || shown.isEmpty ? null : '${peso.format(total)} total',
        ),
        ChoiceStrip<_LogFilter>(
          options: [for (final f in _LogFilter.values) (f, f.label)],
          selected: filter,
          onSelected: onFilter,
        ),
        const SizedBox(height: AppSpacing.md),
        if (shown.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.container),
              border: Border.all(color: context.tokens.hairline),
            ),
            child: const EmptyState(icon: Icons.receipt_long_outlined, message: 'Nothing recorded yet'),
          )
        else
          ListSurface(children: [for (final r in shown) _LogRowView(row: r, onEdit: onEdit, onDelete: onDelete)]),
      ],
    );
  }
}

class _LogRowView extends StatelessWidget {
  const _LogRowView({required this.row, required this.onEdit, required this.onDelete});

  final _LogRow row;
  final ValueChanged<MoneyEntry> onEdit;
  final ValueChanged<MoneyEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final entry = row.entry;
    return InkWell(
      onTap: entry == null ? null : () => onEdit(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 104, child: Text(_day.format(row.at), style: context.text.bodySmall)),
            SizedBox(
              width: 112,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(label: row.filter.pill),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(row.detail, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              peso.format(row.amount),
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: kTabularFigures),
            ),
            SizedBox(
              width: 96,
              child: entry == null
                  ? Tooltip(
                      message: 'Recorded from Inventory',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.inventory_2_outlined, size: 16, color: context.tokens.mutedText),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit',
                          onPressed: () => onEdit(entry),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete',
                          onPressed: () => onDelete(entry),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
