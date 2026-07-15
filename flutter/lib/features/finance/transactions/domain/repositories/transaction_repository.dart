import 'package:finance_ai/core/failure/result.dart';
import 'package:finance_ai/features/finance/transactions/domain/entities/transaction_entity.dart';

abstract interface class TransactionRepository {
  Future<Result<TransactionEntity>> create(TransactionEntity transaction);
  Future<Result<void>> softDelete(String id);
  Future<Result<List<TransactionEntity>>> list({DateTime? cursor, int limit = 30});
}
