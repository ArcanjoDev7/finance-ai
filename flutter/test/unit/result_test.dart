import 'package:finance_ai/core/failure/result.dart';
import 'package:finance_ai/features/chat_ai/presentation/chat_page.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
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

  test(
    'Command suggestions appear after typing at sign and filter by prefix',
    () {
      expect(filterFinanceCommandSuggestions('@'), financeCommandTags);
      expect(filterFinanceCommandSuggestions('@cr'), ['@cripto']);
      expect(filterFinanceCommandSuggestions('@cripto '), isEmpty);
      expect(filterFinanceCommandSuggestions('comprei'), isEmpty);
    },
  );

  test('Crypto, stock and bank labels are normalized for display', () {
    expect(canonicalCryptoTicker('cmprei bnb por 100'), 'BNB');
    expect(financeCryptoLabel('ethereum'), 'ETH');
    expect(financeInvestmentLabel('petr4'), 'PETR4');
    expect(financeInvestmentType('PETR4'), 'Ação');
    expect(canonicalMarketAssetName('cmprei petr4 por 100'), 'PETR4');
    expect(canonicalBankName('recebi no Nubank'), 'Nubank');

    final income = parseTaggedFinanceCommand('@receita Nubank 500', 500);
    expect(income?['bank'], 'Nubank');
    expect(income?['description'], 'Recebimento · Nubank');
    expect(
      parseTaggedFinanceCommand('@receita 6000', 6000)?['description'],
      'Receita',
    );
    final crypto = parseTaggedFinanceCommand('@cripto bnb 100', 100);
    expect(crypto?['investment'], 'BNB');
    expect(canonicalCryptoTicker('gastei 500 conto na dogcoin'), 'DOGE');
    expect(
      cleanFinanceDescription(
        'cmprei um lanche por 25 reais',
        fallback: 'Despesa',
      ),
      'Um lanche',
    );
  });

  test('Timeline counts income, expense, investment and crypto operations', () {
    final timeline = buildFinanceTimeline(
      entries: [
        FinanceEntry(
          id: 'income-1',
          description: 'Salário',
          category: 'Receitas',
          amount: 4000,
          kind: EntryKind.income,
          date: DateTime(2026, 7, 20),
        ),
      ],
      investments: [
        InvestmentItem(
          id: 'investment-1',
          date: DateTime(2026, 7, 21),
          name: 'CDB',
          institution: 'Conta principal',
          type: 'Renda fixa',
          amount: 500,
          yieldDescription: 'Sincronizado',
        ),
      ],
      cryptos: [
        CryptoItem(
          id: 'crypto-1',
          date: DateTime(2026, 7, 22),
          asset: 'DOGE',
          amount: 500,
          operation: 'Compra',
        ),
      ],
    );

    expect(timeline, hasLength(3));
    expect(timeline.first.kind, EntryKind.cryptoBuy);
    expect(timeline.first.description, 'DOGE · Compra');
    expect(timeline[1].kind, EntryKind.investment);
    expect(timeline.last.kind, EntryKind.income);
  });
}
