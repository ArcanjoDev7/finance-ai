import 'package:finance_ai/core/failure/result.dart';
import 'package:finance_ai/features/chat_ai/presentation/chat_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Result routes a success to the success branch', () {
    const result = Success<int>(42);

    final value = result.when(success: (number) => number, failure: (_) => -1);

    expect(value, 42);
  });

  test('Chat history lives only in the current dashboard session', () {
    final openSession = ChatSessionState();
    openSession.messages.add(const ChatMessage('Mensagem da sessão'));

    expect(openSession.messages.single.text, 'Mensagem da sessão');
    expect(ChatSessionState().messages, isEmpty);
  });

  test('Tagged commands choose their destination without AI inference', () {
    expect(
      parseTaggedFinanceCommand('@dispesa mercado 50', 50)?['intent'],
      'create_expense',
    );
    expect(
      parseTaggedFinanceCommand('@receita salario 4000', 4000)?['intent'],
      'create_income',
    );
    expect(
      parseTaggedFinanceCommand('@investimento CDB 500', 500)?['intent'],
      'create_investment',
    );
    expect(
      parseTaggedFinanceCommand('@cripto Bitcoin 100', 100)?['intent'],
      'create_crypto_purchase',
    );
    expect(
      parseTaggedFinanceCommand('@cartao mercado 80', 80)?['account'],
      'Cartão',
    );
  });
}
