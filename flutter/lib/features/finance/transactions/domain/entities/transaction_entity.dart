enum TransactionKind { income, expense, transfer, refund, investment, cryptoBuy, cryptoSell }

class TransactionEntity {
  const TransactionEntity({required this.id, required this.walletId, required this.type, required this.amountMinor, required this.currencyCode, required this.occurredAt, this.accountId, this.destinationAccountId, this.categoryId, this.description = '', this.notes});
  final String id;
  final String walletId;
  final String? accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final TransactionKind type;
  final int amountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final DateTime occurredAt;
}
