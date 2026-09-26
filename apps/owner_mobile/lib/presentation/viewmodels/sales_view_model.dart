import 'package:flutter/foundation.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/calculations/sales_grouping.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/repositories/sale_repository.dart';

/// The Sales tab: every sale in the chosen period, grouped by day. Read-only.
class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this._repository, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SaleRepository _repository;
  final DateTime Function() _clock;

  /// The periods the tab offers.
  static const ranges = [ReportRange.today, ReportRange.last7Days, ReportRange.last30Days];

  List<Sale> _all = const [];
  bool _loaded = false;
  ReportRange _range = ReportRange.today;

  bool get loaded => _loaded;
  ReportRange get range => _range;
  DateTime get now => _clock();

  List<Sale> get sales => filterSalesByRange(_all, _range, _clock());
  List<SalesDay> get days => groupSalesByDay(sales);
  ReportSummary get summary => summarize(sales);

  /// Null once the sale is gone, e.g. voided on the shop computer.
  Sale? byId(String id) {
    for (final sale in _all) {
      if (sale.id == id) return sale;
    }
    return null;
  }

  void selectRange(ReportRange range) {
    if (range == _range) return;
    _range = range;
    notifyListeners();
  }

  Future<void> load() async {
    _all = await _repository.getAll();
    _loaded = true;
    notifyListeners();
  }
}
