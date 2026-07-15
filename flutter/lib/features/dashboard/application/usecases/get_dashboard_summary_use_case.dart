import 'package:finance_ai/core/failure/result.dart';
import 'package:finance_ai/features/dashboard/domain/entities/dashboard_summary_entity.dart';
import 'package:finance_ai/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardSummaryUseCase {
  const GetDashboardSummaryUseCase(this._repository);
  final DashboardRepository _repository;
  Future<Result<DashboardSummaryEntity>> call({required DateTime from, required DateTime to}) => _repository.getSummary(from: from, to: to);
}
