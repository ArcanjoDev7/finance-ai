import 'package:finance_ai/core/services/supabase_web_client.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.onTransactionCreated, required this.onInvestmentCreated, required this.onCryptoCreated});
  final ValueChanged<FinanceEntry> onTransactionCreated;
  final ValueChanged<InvestmentItem> onInvestmentCreated;
  final ValueChanged<CryptoItem> onCryptoCreated;
  @override State<ChatPage> createState() => _ChatPageState();
}

class _Message { const _Message(this.text, {this.user = false, this.action}); final String text; final bool user; final Map<String, dynamic>? action; }

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _messages = <_Message>[];
  String? _token;
  bool _sending = false;

  @override void initState() { super.initState(); SupabaseWebClient.instance.restoredSession().then((value) { if (mounted && value != null) setState(() => _token = value); }); }
  @override void dispose() { _input.dispose(); super.dispose(); }

  Future<void> _authenticate() async {
    final email = TextEditingController(); final password = TextEditingController(); var create = false;
    final result = await showDialog<AuthResult>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(create ? 'Criar conta' : 'Entrar no Finance AI'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Text(create ? 'Crie sua conta para salvar os dados no Finance AI.' : 'Entre para sincronizar seus dados com segurança.'), const SizedBox(height: 16), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')), const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha', helperText: 'Mínimo de 6 caracteres'))]),
      actions: [TextButton(onPressed: () => setDialogState(() => create = !create), child: Text(create ? 'Já tenho conta' : 'Criar conta')), TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (password.text.length < 6) { ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('A senha precisa ter pelo menos 6 caracteres.'))); return; } try { final value = create ? await SupabaseWebClient.instance.signUp(email.text.trim(), password.text) : await SupabaseWebClient.instance.signIn(email.text.trim(), password.text); if (dialogContext.mounted) Navigator.pop(dialogContext, value); } catch (_) { if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(create ? 'Não foi possível criar a conta. Tente outro e-mail.' : 'Não foi possível entrar. Confira e-mail e senha.'))); } }, child: Text(create ? 'Criar conta' : 'Entrar'))],
    )));
    email.dispose(); password.dispose();
    if (!mounted || result == null) return;
    if (result.accessToken != null) { setState(() => _token = result.accessToken); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta conectada. Seus dados serão sincronizados.'))); }
    if (result.requiresEmailConfirmation) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta criada. Confirme o e-mail e entre para sincronizar os dados.')));
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _input.text).trim(); if (text.isEmpty || _sending) return;
    setState(() { _messages.add(_Message(text, user: true)); _input.clear(); _sending = true; });
    try {
      final action = _token == null ? _parse(text) : Map<String, dynamic>.from((await SupabaseWebClient.instance.chat(_token!, {'message': text, 'idempotencyKey': _key()}))['action'] as Map? ?? const {});
      _apply(action);
      if (mounted) setState(() => _messages.add(_Message(_response(action), action: action)));
    } on AiRequestException catch (error) { if (mounted) setState(() => _messages.add(_Message(_aiErrorMessageWithProvider(error)))); }
    catch (_) { if (mounted) setState(() => _messages.add(const _Message('Não consegui processar esse comando. Tente novamente.'))); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Map<String, dynamic> _parse(String text) {
    final source = text.toLowerCase(); final match = RegExp(r'(\d+(?:[\.,]\d{1,2})?)').firstMatch(source); final amount = double.tryParse((match?.group(1) ?? '').replaceAll(',', '.'));
    if (source.contains('gastei') || source.contains('paguei')) return {'intent': 'create_expense', 'amount': amount, 'description': text, 'category': source.contains('mercado') ? 'Alimentação' : 'Outros'};
    if (source.contains('recebi') || source.contains('salário') || source.contains('salario')) return {'intent': 'create_income', 'amount': amount, 'description': text, 'category': 'Receitas'};
    if (source.contains('vendi') || source.contains('saquei')) return {'intent': 'create_crypto_sale', 'amount': amount, 'investment': source.contains('bitcoin') || source.contains('btc') ? 'Bitcoin' : 'Cripto'};
    if (source.contains('converti') || source.contains('conversão') || source.contains('conversao')) return {'intent': 'create_crypto_conversion', 'amount': amount, 'investment': source.contains('bitcoin') || source.contains('btc') ? 'Bitcoin' : 'Cripto'};
    if (source.contains('bitcoin') || source.contains('btc') || source.contains('ethereum') || source.contains('eth')) return {'intent': 'create_crypto_purchase', 'amount': amount, 'investment': source.contains('ethereum') || source.contains('eth') ? 'Ethereum' : 'Bitcoin'};
    if (source.contains('cdb') || source.contains('investi')) return {'intent': 'create_investment', 'amount': amount, 'investment': source.contains('cdb') ? 'CDB' : 'Investimento', 'bank': 'Carteira principal'};
    return {'intent': 'query_summary'};
  }

  void _apply(Map<String, dynamic> action) { final amount = (action['amount'] as num?)?.toDouble(); if (amount == null || amount <= 0) return; final id = _key(); switch (action['intent']) { case 'create_expense': widget.onTransactionCreated(FinanceEntry(id: id, description: '${action['description'] ?? 'Despesa'}', category: '${action['category'] ?? 'Outros'}', amount: amount, kind: EntryKind.expense, date: DateTime.now())); return; case 'create_income': widget.onTransactionCreated(FinanceEntry(id: id, description: '${action['description'] ?? 'Receita'}', category: '${action['category'] ?? 'Receitas'}', amount: amount, kind: EntryKind.income, date: DateTime.now())); return; case 'create_investment': widget.onInvestmentCreated(InvestmentItem(name: '${action['investment'] ?? 'Investimento'}', institution: '${action['bank'] ?? 'Carteira principal'}', type: 'Renda fixa', amount: amount, yieldDescription: 'Registrado pela IA')); return; case 'create_crypto_purchase': widget.onCryptoCreated(CryptoItem(asset: '${action['investment'] ?? 'Bitcoin'}', amount: amount, operation: 'Compra')); return; case 'create_crypto_sale': widget.onCryptoCreated(CryptoItem(asset: '${action['investment'] ?? 'Cripto'}', amount: amount, operation: 'Venda')); return; case 'create_crypto_conversion': widget.onCryptoCreated(CryptoItem(asset: '${action['investment'] ?? 'Cripto'}', amount: amount, operation: 'Conversão')); return; default: return; } }
  String _response(Map<String, dynamic> action) => switch (action['intent']) {'create_expense' => 'Despesa adicionada.', 'create_income' => 'Receita adicionada.', 'create_investment' => 'Investimento adicionado.', 'create_crypto_purchase' => 'Compra de cripto registrada.', _ => 'Faça login para consultar dados sincronizados. Sem login, você pode testar lançamentos na sessão atual.'};
  String _aiErrorMessage(String code) => switch (code) { 'AI_CONFIGURATION_REQUIRED' => 'A IA ainda não está configurada no Supabase. Falta validar a chave ou o modelo da OpenAI.', 'AI_PROVIDER_UNAVAILABLE' => 'A OpenAI recusou a solicitação. Verifique a chave, o modelo configurado e os créditos da conta OpenAI.', 'ACTION_PERSISTENCE_FAILED' => 'A IA entendeu o comando, mas não conseguiu salvar o lançamento no banco. A função precisa ser publicada com a atualização atual.', 'UNAUTHORIZED' => 'Sua sessão expirou. Saia e entre novamente.', _ => 'A IA não concluiu o comando ($code).'};
  String _aiErrorMessageWithProvider(AiRequestException error) {
    if (error.code != 'AI_PROVIDER_UNAVAILABLE') return _aiErrorMessage(error.code);
    final detail = error.providerStatus == null ? '' : ' Diagnóstico OpenAI: HTTP ${error.providerStatus}${error.providerCode == null ? '' : ' (${error.providerCode})'}.';
    return 'A OpenAI recusou a solicitação.$detail';
  }
  String _key() {
    final raw = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final value = raw.substring(raw.length - 12).padLeft(12, '0');
    return '00000000-0000-4000-8000-$value';
  }

  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(28, 24, 28, 12), child: Row(children: [const CircleAvatar(backgroundColor: Color(0xFF52318E), child: Icon(Icons.auto_awesome)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Assistente Financeiro', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), Text(_token == null ? 'Modo de teste · entre para salvar na sua conta' : 'Conta conectada · dados sincronizados', style: const TextStyle(color: Colors.white70))])), if (_token == null) OutlinedButton(onPressed: _authenticate, child: const Text('Entrar ou criar conta'))])),
    Expanded(child: _messages.isEmpty ? _Empty(onSend: _send) : ListView(padding: const EdgeInsets.symmetric(horizontal: 28), children: _messages.map((message) => _Bubble(message: message)).toList())), if (_sending) const LinearProgressIndicator(minHeight: 2), Padding(padding: const EdgeInsets.all(24), child: Row(children: [Expanded(child: TextField(controller: _input, onSubmitted: (_) => _send(), decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_awesome), hintText: 'Ex.: Gastei R\$ 50 no mercado'))), const SizedBox(width: 12), FilledButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Icons.arrow_upward), label: const Text('Enviar'))]))
  ]);
}

class _Empty extends StatelessWidget { const _Empty({required this.onSend}); final Future<void> Function([String?]) onSend; @override Widget build(BuildContext context) { const items = ['Gastei R\$ 50 no mercado', 'Recebi R\$ 4.000 de salário', 'Investi R\$ 5.000 no CDB', 'Comprei R\$ 1.500 de Bitcoin']; return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.auto_awesome, size: 54, color: Color(0xFFC4B5FD)), const SizedBox(height: 12), Text('Como posso ajudar com suas finanças?', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 18), Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: items.map((item) => ActionChip(onPressed: () => onSend(item), label: Text(item))).toList())])); } }
class _Bubble extends StatelessWidget { const _Bubble({required this.message}); final _Message message; @override Widget build(BuildContext context) => Align(alignment: message.user ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), constraints: const BoxConstraints(maxWidth: 660), decoration: BoxDecoration(color: message.user ? const Color(0xFF59368F) : const Color(0xFF211C29), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(message.user ? 'Você' : 'Finance AI', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(message.text), if (message.action?['amount'] != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Ação registrada · R\$ ${(message.action!['amount'] as num).toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(color: Color(0xFF6EE7B7))))]))); }
