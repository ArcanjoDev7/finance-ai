import 'package:finance_ai/core/services/supabase_web_client.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.onTransactionCreated, required this.onInvestmentCreated});
  final ValueChanged<FinanceEntry> onTransactionCreated;
  final ValueChanged<InvestmentItem> onInvestmentCreated;
  @override State<ChatPage> createState() => _ChatPageState();
}

class _ChatMessage { const _ChatMessage({required this.text, required this.fromUser, this.action}); final String text; final bool fromUser; final Map<String, dynamic>? action; }

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _messages = <_ChatMessage>[];
  String? _token;
  bool _sending = false;

  @override void dispose() { _input.dispose(); super.dispose(); }

  Future<void> _signIn() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final token = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Entrar no Finance AI'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')), const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), FilledButton(onPressed: () async { try { final value = await SupabaseWebClient.instance.signIn(email.text.trim(), password.text); if (dialogContext.mounted) Navigator.pop(dialogContext, value); } catch (_) { if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Não foi possível entrar. Confira e-mail e senha.'))); } }, child: const Text('Entrar'))]));
    email.dispose(); password.dispose();
    if (token != null && mounted) { setState(() => _token = token); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta conectada. Seus comandos serão sincronizados.'))); }
  }

  Future<void> _send([String? suggested]) async {
    final text = (suggested ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() { _messages.add(_ChatMessage(text: text, fromUser: true)); _input.clear(); _sending = true; });
    try {
      Map<String, dynamic> action;
      if (_token == null) {
        action = _localAction(text);
      } else {
        final data = await SupabaseWebClient.instance.chat(_token!, {'message': text, 'idempotencyKey': _idempotencyKey()});
        action = Map<String, dynamic>.from(data['action'] as Map? ?? const {});
      }
      _applyAction(action);
      if (mounted) setState(() => _messages.add(_ChatMessage(text: _actionMessage(action), fromUser: false, action: action)));
    } catch (_) {
      if (mounted) setState(() => _messages.add(const _ChatMessage(text: 'Não consegui processar esse comando agora. Tente novamente.', fromUser: false)));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Map<String, dynamic> _localAction(String message) {
    final normalized = message.toLowerCase();
    final value = RegExp(r'(\d+(?:[\.,]\d{1,2})?)').firstMatch(normalized)?.group(1)?.replaceAll(',', '.');
    final amount = double.tryParse(value ?? '');
    if (normalized.contains('gastei') || normalized.contains('paguei')) return {'intent': 'create_expense', 'amount': amount, 'description': _description(message), 'category': normalized.contains('mercado') ? 'Alimentação' : 'Outros'};
    if (normalized.contains('recebi') || normalized.contains('salário') || normalized.contains('salario')) return {'intent': 'create_income', 'amount': amount, 'description': _description(message), 'category': 'Receitas'};
    if (normalized.contains('cdb') || normalized.contains('investi')) return {'intent': 'create_investment', 'amount': amount, 'investment': normalized.contains('cdb') ? 'CDB' : 'Investimento', 'bank': 'Carteira principal'};
    if (normalized.contains('bitcoin') || normalized.contains('btc')) return {'intent': 'create_crypto_purchase', 'amount': amount, 'investment': 'Bitcoin'};
    return {'intent': 'query_summary'};
  }

  String _description(String message) { final text = message.trim(); return text.isEmpty ? 'Lançamento pelo assistente' : '${text[0].toUpperCase()}${text.substring(1)}'; }
  void _applyAction(Map<String, dynamic> action) {
    final amount = (action['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) return;
    switch (action['intent']) {
      case 'create_expense': widget.onTransactionCreated(FinanceEntry(id: _idempotencyKey(), description: '${action['description'] ?? 'Despesa'}', category: '${action['category'] ?? 'Outros'}', amount: amount, kind: EntryKind.expense, date: DateTime.now()));
      case 'create_income': widget.onTransactionCreated(FinanceEntry(id: _idempotencyKey(), description: '${action['description'] ?? 'Receita'}', category: '${action['category'] ?? 'Receitas'}', amount: amount, kind: EntryKind.income, date: DateTime.now()));
      case 'create_investment': widget.onInvestmentCreated(InvestmentItem(name: '${action['investment'] ?? 'Investimento'}', institution: '${action['bank'] ?? 'Carteira principal'}', type: '${action['investment'] ?? 'Investimento'}', amount: amount, yieldDescription: 'Registrado pelo assistente'));
      case 'create_crypto_purchase': widget.onInvestmentCreated(InvestmentItem(name: '${action['investment'] ?? 'Bitcoin'}', institution: 'Carteira de cripto', type: 'Criptomoeda', amount: amount, yieldDescription: 'Registrado pelo assistente'));
    }
  }

  String _idempotencyKey() {
    final value = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$value';
  }
  String _actionMessage(Map<String, dynamic> action) => switch (action['intent']) { 'create_expense' => 'Despesa adicionada com sucesso.', 'create_income' => 'Receita adicionada com sucesso.', 'create_investment' => 'Investimento adicionado com sucesso.', 'create_crypto_purchase' => 'Compra de cripto registrada com sucesso.', _ => 'Posso registrar receitas, despesas, investimentos ou responder consultas quando sua conta estiver conectada.' };

  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(28, 24, 28, 10), child: _ChatHeader(connected: _token != null, onSignIn: _signIn)),
    Expanded(child: _messages.isEmpty ? _ChatEmpty(onSuggestion: _send) : ListView(padding: const EdgeInsets.fromLTRB(28, 12, 28, 12), children: _messages.map((message) => _MessageBubble(message: message)).toList())),
    if (_sending) const LinearProgressIndicator(minHeight: 2),
    Padding(padding: const EdgeInsets.all(24), child: _ChatInput(controller: _input, enabled: !_sending, onSubmit: _send)),
  ]);
}

class _ChatHeader extends StatelessWidget { const _ChatHeader({required this.connected, required this.onSignIn}); final bool connected; final VoidCallback onSignIn; @override Widget build(BuildContext context) => Row(children: [const CircleAvatar(backgroundColor: Color(0xFF52318E), child: Icon(Icons.auto_awesome)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Assistente Financeiro', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), Text(connected ? 'Conta conectada · comandos sincronizados' : 'Modo de teste · entre para sincronizar', style: const TextStyle(color: Colors.white70))])), if (!connected) OutlinedButton(onPressed: onSignIn, child: const Text('Entrar'))]); }
class _ChatEmpty extends StatelessWidget { const _ChatEmpty({required this.onSuggestion}); final ValueChanged<String> onSuggestion; @override Widget build(BuildContext context) { const suggestions = ['Gastei R\$ 50 no mercado', 'Quanto gastei este mês?', 'Investi R\$ 5.000 no CDB', 'Comprei R\$ 1.500 de Bitcoin']; return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.auto_awesome, size: 52, color: Color(0xFFC4B5FD)), const SizedBox(height: 16), Text('Como posso ajudar com suas finanças?', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 10), const Text('Use linguagem natural. Comandos simples são registrados sem confirmação.', textAlign: TextAlign.center), const SizedBox(height: 22), Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: suggestions.map((value) => ActionChip(label: Text(value), onPressed: () => onSuggestion(value))).toList())]))); } }
class _MessageBubble extends StatelessWidget { const _MessageBubble({required this.message}); final _ChatMessage message; @override Widget build(BuildContext context) => Align(alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), constraints: const BoxConstraints(maxWidth: 660), decoration: BoxDecoration(color: message.fromUser ? const Color(0xFF59368F) : const Color(0xFF211C29), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(message.fromUser ? 'Você' : 'Finance AI', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(message.text), if (message.action?['amount'] != null) ...[const SizedBox(height: 12), _ActionCard(action: message.action!)] ]))); }
class _ActionCard extends StatelessWidget { const _ActionCard({required this.action}); final Map<String, dynamic> action; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0x3310B981), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF34D399))), child: Row(children: [const Icon(Icons.check_circle_outline, color: Color(0xFF34D399)), const SizedBox(width: 10), Expanded(child: Text('${action['intent']} · R\$ ${(action['amount'] as num).toStringAsFixed(2).replaceAll('.', ',')}'))])); }
class _ChatInput extends StatelessWidget { const _ChatInput({required this.controller, required this.enabled, required this.onSubmit}); final TextEditingController controller; final bool enabled; final Future<void> Function([String?]) onSubmit; @override Widget build(BuildContext context) => Row(children: [Expanded(child: TextField(controller: controller, enabled: enabled, onSubmitted: (_) => onSubmit(), decoration: const InputDecoration(hintText: 'Ex.: Gastei R\$ 50 no mercado', prefixIcon: Icon(Icons.auto_awesome)))), const SizedBox(width: 12), FilledButton.icon(onPressed: enabled ? () => onSubmit() : null, icon: const Icon(Icons.arrow_upward), label: const Text('Enviar'))]); }
