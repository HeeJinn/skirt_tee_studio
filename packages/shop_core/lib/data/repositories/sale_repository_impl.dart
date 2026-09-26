import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/local/sale_local_data_source.dart';
import '../models/sale_model.dart';

class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl(this._localDataSource);
  final SaleLocalDataSource _localDataSource;

  @override
  Future<void> recordSale(Sale sale) =>
      _localDataSource.recordSale(SaleModel.fromEntity(sale));

  @override
  Future<List<Sale>> getAll() => _localDataSource.getAll();

  @override
  Future<void> voidSale(String id) => _localDataSource.voidSale(id);
}
