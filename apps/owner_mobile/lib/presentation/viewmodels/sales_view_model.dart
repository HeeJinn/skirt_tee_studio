import 'package:flutter/foundation.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/calculations/sales_grouping.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/repositories/sale_repository.dart';

import '../../core/period.dart';

/// The Sales tab: every sale on a chosen day or in a chosen month, grouped
/// by day. Read-only.
class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this._repository, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SaleRepository _repository;
  final DateTime Function() _clock;

  /// The kinds of period the tab offers.
  static const kinds = [PeriodKind.day, PeriodKind.month];

  List<Sale> _all = const [];
  bool _loaded = false;
  Period? _period;

  bool get loaded => _loaded;
  DateTime get now => _clock();

  /// Opens on today.
  Period get period => _period ??= Period.day(_clock());

  /// When the oldest sale was rung up; null before the first.
  DateTime? get earliest =>
      _all.isEmpty ? null : _all.map((s) => s.dateTime).reduce((a, b) => a.isBefore(b) ? a : b);

  List<Sale> get sales => _all.where((s) => period.contains(s.dateTime)).toList();
  List<SalesDay> get days => groupSalesByDay(sales);
  ReportSummary get summary => summarize(sales);

  /// Null once the sale is gone, e.g. voided on the shop computer.
  Sale? byId(String id) {
    for (final sale in _all) {
      if (sale.id == id) return sale;
    }
    return null;
  }

  void selectPeriod(Period period) {
    if (period == this.period) return;
    _period = period;
    notifyListeners();
  }

  Future<void> load() async {
    _all = await _repository.getAll();
    _loaded = true;
    notifyListeners();
  }
}
