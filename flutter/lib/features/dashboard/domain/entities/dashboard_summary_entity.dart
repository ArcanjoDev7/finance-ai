class DashboardSummaryEntity {
  const DashboardSummaryEntity({required this.balanceMinor, required this.netWorthMinor, required this.incomeMinor, required this.expenseMinor, required this.investedMinor});
  final int balanceMinor;
  final int netWorthMinor;
  final int incomeMinor;
  final int expenseMinor;
  final int investedMinor;
  int get monthlyResultMinor => incomeMinor - expenseMinor;
}
