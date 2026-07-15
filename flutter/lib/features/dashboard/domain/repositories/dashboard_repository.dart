import 'package:finance_ai/core/failure/result.dart';
import 'package:finance_ai/features/dashboard/domain/entities/dashboard_summary_entity.dart';

abstract interface class DashboardRepository {
  Future<Result<DashboardSummaryEntity>> getSummary({required DateTime from, required DateTime to});
}
