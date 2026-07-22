import 'package:finance_ai/app/theme/app_theme.dart';
import 'package:finance_ai/core/services/supabase_web_client.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.session,
    required this.onTransactionCreated,
    required this.onInvestmentCreated,
    required this.onCryptoCreated,
    required this.onAccountReset,
  });
  final ChatSessionState session;
  final ValueChanged<FinanceEntry> onTransactionCreated;
  final ValueChanged<InvestmentItem> onInvestmentCreated;
  final ValueChanged<CryptoItem> onCryptoCreated;
  final Future<void> Function() onAccountReset;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class ChatSessionState {
  final List<ChatMessage> messages = [];
  String? sessionId;
}

class ChatMessage {
  const ChatMessage(this.text, {this.user = false, this.action});
  final String text;
  final bool user;
  final Map<String, dynamic>? action;
}

const financeCommandTags = <String>[
  '@despesa',
  '@receita',
  '@investimento',
  '@cripto',
  '@cartao',
];

List<String> filterFinanceCommandSuggestions(String input) {
  final query = input.trimLeft().toLowerCase();
  if (!query.startsWith('@') || query.contains(RegExp(r'\s'))) {
    return const [];
  }
  return financeCommandTags
      .where((command) => command.startsWith(query))
      .toList(growable: false);
}

Map<String, dynamic>? parseTaggedFinanceCommand(
  String original,
  double? amount,
) {
  final source = original.toLowerCase();
  final match = RegExp(
    r'^@(cripto|crypto|despesa|dispesa|gasto|saida|cartao|receita|entrada|salario|investimento|investir)\b\s*(.*)$',
  ).firstMatch(source.trim());
  if (match == null) return null;
  final tag = match.group(1)!;
  final details = match.group(2)!.trim();
  if (amount == null) {
    return {
      'intent': 'needs_clarification',
      'answer': 'Informe o valor no mesmo comando. Ex.: @$tag Bitcoin 100',
    };
  }
  if (['despesa', 'dispesa', 'gasto', 'saida', 'cartao'].contains(tag)) {
    return {
      'intent': 'create_expense',
      'amount': amount,
      'description': original,
      'category': details.contains('mercado') ? 'Alimentação' : 'Outros',
      'account':
          tag == 'cartao' ||
              details.contains('cartão') ||
              details.contains('cartao')
          ? 'Cartão'
          : 'Conta principal',
    };
  }
  if (['receita', 'entrada', 'salario'].contains(tag)) {
    return {
      'intent': 'create_income',
      'amount': amount,
      'description': original,
      'category': 'Receitas',
    };
  }
  if (tag == 'investimento' || tag == 'investir') {
    return {
      'intent': 'create_investment',
      'amount': amount,
      'investment': details.isEmpty ? 'Investimento' : details,
      'bank': 'Carteira principal',
    };
  }
  return {
    'intent': details.contains('vendi') || details.contains('venda')
        ? 'create_crypto_sale'
        : details.contains('converti') || details.contains('troquei')
        ? 'create_crypto_conversion'
        : 'create_crypto_purchase',
    'amount': amount,
    'investment': details.contains('ethereum') || details.contains('eth')
        ? 'Ethereum'
        : details.contains('bitcoin') || details.contains('btc')
        ? 'Bitcoin'
        : 'Cripto',
  };
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _messagesController = ScrollController();
  String? _token;
  bool _sending = false;

  List<ChatMessage> get _messages => widget.session.messages;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    SupabaseWebClient.instance.restoredSession().then((value) {
      if (mounted && value != null) setState(() => _token = value);
    });
    if (_messages.isNotEmpty) _scrollToLatestMessage();
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _inputFocus.dispose();
    _messagesController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _selectCommand(String command) {
    final value = '$command ';
    _input.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _inputFocus.requestFocus();
  }

  void _startCommand() {
    _input.value = const TextEditingValue(
      text: '@',
      selection: TextSelection.collapsed(offset: 1),
    );
    _inputFocus.requestFocus();
  }

  void _scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesController.hasClients) return;
      _messagesController.animateTo(
        _messagesController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _authenticate() async {
    final email = TextEditingController();
    final password = TextEditingController();
    var create = false;
    final result = await showDialog<AuthResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(create ? 'Criar conta' : 'Entrar no Finance AI'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                create
                    ? 'Crie sua conta para salvar os dados no Finance AI.'
                    : 'Entre para sincronizar seus dados com segurança.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  helperText: 'Mínimo de 6 caracteres',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => setDialogState(() => create = !create),
              child: Text(create ? 'Já tenho conta' : 'Criar conta'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (password.text.length < 6) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A senha precisa ter pelo menos 6 caracteres.',
                      ),
                    ),
                  );
                  return;
                }
                try {
                  final value = create
                      ? await SupabaseWebClient.instance.signUp(
                          email.text.trim(),
                          password.text,
                        )
                      : await SupabaseWebClient.instance.signIn(
                          email.text.trim(),
                          password.text,
                        );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, value);
                  }
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          create
                              ? 'Não foi possível criar a conta. Tente outro e-mail.'
                              : 'Não foi possível entrar. Confira e-mail e senha.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(create ? 'Criar conta' : 'Entrar'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
    if (!mounted || result == null) return;
    if (result.accessToken != null) {
      setState(() => _token = result.accessToken);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta conectada. Seus dados serão sincronizados.'),
        ),
      );
    }
    if (result.requiresEmailConfirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conta criada. Confirme o e-mail e entre para sincronizar os dados.',
          ),
        ),
      );
    }
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(ChatMessage(text, user: true));
      _input.clear();
      _sending = true;
    });
    _scrollToLatestMessage();
    try {
      final Map<String, dynamic> action;
      if (_token == null) {
        action = _parse(text);
      } else {
        final response = await SupabaseWebClient.instance.chat(_token!, {
          'message': text,
          'idempotencyKey': _key(),
          if (widget.session.sessionId != null)
            'sessionId': widget.session.sessionId,
        });
        final returnedSessionId = response['sessionId'];
        if (returnedSessionId is String) {
          widget.session.sessionId = returnedSessionId;
        }
        action = Map<String, dynamic>.from(
          response['action'] as Map? ?? const {},
        );
      }
      _apply(action);
      if (mounted) {
        setState(
          () => _messages.add(ChatMessage(_response(action), action: action)),
        );
        _scrollToLatestMessage();
      }
    } on AiRequestException catch (error) {
      if (error.code == 'UNAUTHORIZED') {
        await SupabaseWebClient.instance.signOut();
        if (mounted) {
          setState(() {
            _token = null;
            _messages.add(
              const ChatMessage(
                'Sua sessão expirou. Entre novamente para continuar salvando e consultando os dados da sua conta.',
              ),
            );
          });
          _scrollToLatestMessage();
        }
        return;
      }
      if (mounted) {
        setState(
          () => _messages.add(ChatMessage(_aiErrorMessageWithProvider(error))),
        );
        _scrollToLatestMessage();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(
            const ChatMessage(
              'Não consegui processar esse comando. Tente novamente.',
            ),
          ),
        );
        _scrollToLatestMessage();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Map<String, dynamic> _parse(String text) {
    final source = text.toLowerCase();
    final amount = _parseAmount(source);
    final tagged = parseTaggedFinanceCommand(text, amount);
    if (tagged != null) return tagged;
    if ((source.contains('zerar') ||
            source.contains('limpar') ||
            source.contains('reiniciar')) &&
        source.contains('conta')) {
      return {'intent': 'reset_account'};
    }
    if (source.contains('gastei') ||
        source.contains('paguei') ||
        source.contains('comprei') ||
        source.contains('adquiri')) {
      return {
        'intent': 'create_expense',
        'amount': amount,
        'description': text,
        'category': source.contains('mercado') ? 'Alimentação' : 'Outros',
      };
    }
    if (source.contains('recebi') ||
        source.contains('salário') ||
        source.contains('salario')) {
      return {
        'intent': 'create_income',
        'amount': amount,
        'description': text,
        'category': 'Receitas',
      };
    }
    if (source.contains('vendi') || source.contains('saquei')) {
      return {
        'intent': 'create_crypto_sale',
        'amount': amount,
        'investment': source.contains('bitcoin') || source.contains('btc')
            ? 'Bitcoin'
            : 'Cripto',
      };
    }
    if (source.contains('converti') ||
        source.contains('conversão') ||
        source.contains('conversao')) {
      return {
        'intent': 'create_crypto_conversion',
        'amount': amount,
        'investment': source.contains('bitcoin') || source.contains('btc')
            ? 'Bitcoin'
            : 'Cripto',
      };
    }
    if (source.contains('bitcoin') ||
        source.contains('btc') ||
        source.contains('ethereum') ||
        source.contains('eth')) {
      return {
        'intent': 'create_crypto_purchase',
        'amount': amount,
        'investment': source.contains('ethereum') || source.contains('eth')
            ? 'Ethereum'
            : 'Bitcoin',
      };
    }
    if (source.contains('cdb') || source.contains('investi')) {
      return {
        'intent': 'create_investment',
        'amount': amount,
        'investment': source.contains('cdb') ? 'CDB' : 'Investimento',
        'bank': 'Carteira principal',
      };
    }
    return {'intent': 'query_summary'};
  }

  double? _parseAmount(String source) {
    final raw = RegExp(r'\d[\d.,]*').firstMatch(source)?.group(0);
    if (raw == null) return null;
    final hasDot = raw.contains('.');
    final hasComma = raw.contains(',');
    if (!hasDot && !hasComma) return double.tryParse(raw);
    if (hasDot && hasComma) {
      final decimalSeparator = raw.lastIndexOf('.') > raw.lastIndexOf(',')
          ? '.'
          : ',';
      final normalized = raw
          .replaceAll(decimalSeparator == '.' ? ',' : '.', '')
          .replaceAll(decimalSeparator, '.');
      return double.tryParse(normalized);
    }
    final separator = hasDot ? '.' : ',';
    final fractionSize = raw.length - raw.lastIndexOf(separator) - 1;
    final normalized = fractionSize == 3
        ? raw.replaceAll(separator, '')
        : raw.replaceAll(separator, '.');
    return double.tryParse(normalized);
  }

  void _apply(Map<String, dynamic> action) {
    final nestedActions = action['actions'];
    if (nestedActions is List) {
      for (final nested in nestedActions.whereType<Map>()) {
        _apply(Map<String, dynamic>.from(nested));
      }
      return;
    }
    if (action['intent'] == 'reset_account') {
      widget.onAccountReset();
      return;
    }
    if (_token != null &&
        '${action['intent']}'.startsWith('create_') &&
        action['savedTransactionId'] == null) {
      return;
    }
    final amount = (action['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) return;
    final id = _key();
    switch (action['intent']) {
      case 'create_expense':
        final account = '${action['account'] ?? ''}'.toLowerCase();
        widget.onTransactionCreated(
          FinanceEntry(
            id: id,
            description: '${action['description'] ?? 'Despesa'}',
            category: '${action['category'] ?? 'Outros'}',
            amount: amount,
            kind: EntryKind.expense,
            date: DateTime.now(),
            isCard: account.contains('cart'),
          ),
        );
        return;
      case 'create_income':
        widget.onTransactionCreated(
          FinanceEntry(
            id: id,
            description: '${action['description'] ?? 'Receita'}',
            category: '${action['category'] ?? 'Receitas'}',
            amount: amount,
            kind: EntryKind.income,
            date: DateTime.now(),
          ),
        );
        return;
      case 'create_investment':
        widget.onInvestmentCreated(
          InvestmentItem(
            name: '${action['investment'] ?? 'Investimento'}',
            institution: '${action['bank'] ?? 'Carteira principal'}',
            type: 'Renda fixa',
            amount: amount,
            yieldDescription: 'Registrado pela IA',
          ),
        );
        return;
      case 'create_crypto_purchase':
        widget.onCryptoCreated(
          CryptoItem(
            asset: '${action['investment'] ?? 'Bitcoin'}',
            amount: amount,
            operation: 'Compra',
          ),
        );
        return;
      case 'create_crypto_sale':
        widget.onCryptoCreated(
          CryptoItem(
            asset: '${action['investment'] ?? 'Cripto'}',
            amount: amount,
            operation: 'Venda',
          ),
        );
        return;
      case 'create_crypto_conversion':
        widget.onCryptoCreated(
          CryptoItem(
            asset: '${action['investment'] ?? 'Cripto'}',
            amount: amount,
            operation: 'Conversão',
          ),
        );
        return;
      default:
        return;
    }
  }

  String _response(Map<String, dynamic> action) {
    final nestedActions = action['actions'];
    if (nestedActions is List) {
      final responses = nestedActions
          .whereType<Map>()
          .map((nested) => _response(Map<String, dynamic>.from(nested)))
          .where((message) => message.isNotEmpty)
          .toList();
      if (responses.isEmpty) {
        return 'Não consegui identificar as movimentações com segurança.';
      }
      return '${responses.length} movimentações processadas:\n• ${responses.join('\n• ')}';
    }
    final answer = action['answer'];
    if (answer is String && answer.trim().isNotEmpty) return answer;
    if (action['intent'] == 'create_expense') {
      final isCard = '${action['account'] ?? ''}'.toLowerCase().contains(
        'cart',
      );
      return isCard
          ? 'Despesa adicionada à fatura do cartão.'
          : 'Despesa adicionada à conta principal.';
    }
    return switch (action['intent']) {
      'create_income' => 'Receita adicionada.',
      'create_investment' => 'Investimento adicionado.',
      'create_crypto_purchase' => 'Compra de cripto registrada.',
      'create_crypto_sale' => 'Venda de cripto registrada.',
      'reset_account' =>
        'Vou pedir sua confirmação antes de zerar os valores da conta.',
      _ =>
        'Faça login para consultar dados sincronizados. Sem login, você pode testar lançamentos na sessão atual.',
    };
  }

  String _aiErrorMessage(String code) => switch (code) {
    'AI_CONFIGURATION_REQUIRED' =>
      'A IA ainda não está configurada no Supabase. Falta validar a chave ou o modelo do Gemini.',
    'AI_PROVIDER_UNAVAILABLE' =>
      'O Gemini recusou a solicitação. Verifique a chave, o modelo configurado e a cota da conta Google AI.',
    'ACTION_PERSISTENCE_FAILED' =>
      'A IA entendeu o comando, mas não conseguiu salvar o lançamento no banco. A função precisa ser publicada com a atualização atual.',
    'UNAUTHORIZED' => 'Sua sessão expirou. Saia e entre novamente.',
    _ => 'A IA não concluiu o comando ($code).',
  };
  String _aiErrorMessageWithProvider(AiRequestException error) {
    if (error.code == 'AI_REQUEST_FAILED') {
      final detail = error.providerStatus == null
          ? error.providerCode ?? 'erro de rede'
          : 'HTTP ${error.providerStatus} (${error.providerCode ?? 'sem código'})';
      return 'A Function de IA não retornou uma resposta válida. Diagnóstico: $detail.';
    }
    if (error.code != 'AI_PROVIDER_UNAVAILABLE') {
      return _aiErrorMessage(error.code);
    }
    final models = error.providerModels == null || error.providerModels!.isEmpty
        ? ''
        : ' Modelos disponíveis: ${error.providerModels!.join(', ')}.';
    final detail = error.providerStatus == null
        ? ''
        : ' Diagnóstico IA: HTTP ${error.providerStatus}${error.providerCode == null ? '' : ' (${error.providerCode})'}${error.providerMessage == null ? '' : ' — ${error.providerMessage}'}.'
                  .replaceAll('..', '.') +
              models;
    return 'O provedor de IA recusou a solicitação.$detail';
  }

  String _key() {
    final raw = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final value = raw.substring(raw.length - 12).padLeft(12, '0');
    return '00000000-0000-4000-8000-$value';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final commandSuggestions = filterFinanceCommandSuggestions(_input.text);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            compact ? 14 : 24,
            compact ? 16 : 28,
            12,
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF52318E),
                child: Icon(Icons.auto_awesome),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistente Financeiro',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _token == null
                          ? 'Modo de teste · entre para salvar na sua conta'
                          : 'Conta conectada · dados sincronizados',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (_token == null)
                OutlinedButton(
                  onPressed: _authenticate,
                  child: const Text('Entrar ou criar conta'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? _Empty(onStartCommand: _startCommand)
              : ListView(
                  controller: _messagesController,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28),
                  children: _messages
                      .map((message) => _Bubble(message: message))
                      .toList(),
                ),
        ),
        if (_sending) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 24,
            8,
            compact ? 12 : 24,
            compact ? 12 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (commandSuggestions.isNotEmpty) ...[
                _CommandSuggestions(
                  commands: commandSuggestions,
                  onSelected: _selectCommand,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        hintText: 'Digite @ para ver os comandos',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (compact)
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      tooltip: 'Enviar',
                      icon: const Icon(Icons.arrow_upward),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('Enviar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommandSuggestions extends StatelessWidget {
  const _CommandSuggestions({required this.commands, required this.onSelected});

  final List<String> commands;
  final ValueChanged<String> onSelected;

  (IconData, String, Color) _details(String command) => switch (command) {
    '@despesa' => (Icons.arrow_upward_rounded, 'Despesa', AppColors.negative),
    '@receita' => (Icons.arrow_downward_rounded, 'Receita', AppColors.positive),
    '@investimento' => (Icons.show_chart_rounded, 'Investir', AppColors.brand),
    '@cripto' => (Icons.currency_bitcoin_rounded, 'Cripto', AppColors.crypto),
    '@cartao' => (Icons.credit_card_rounded, 'Cartão', Color(0xFF60A5FA)),
    _ => (Icons.alternate_email_rounded, command, Colors.white70),
  };

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF191526),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -4)),
      ],
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: commands.map((command) {
          final details = _details(command);
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ActionChip(
              avatar: Icon(details.$1, size: 18, color: details.$3),
              label: Text(details.$2),
              tooltip: command,
              onPressed: () => onSelected(command),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onStartCommand});
  final VoidCallback onStartCommand;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x557C3AED),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Como posso ajudar?',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Converse normalmente ou use um comando rápido.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A1C43), Color(0xFF191526)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x557C3AED)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.alternate_email_rounded,
                          color: Color(0xFFC4B5FD),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comandos rápidos',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Digite @ e escolha onde salvar',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        onPressed: onStartCommand,
                        tooltip: 'Ver comandos',
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 10,
                    children: [
                      _CommandLegend(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Despesa',
                        color: AppColors.negative,
                      ),
                      _CommandLegend(
                        icon: Icons.arrow_downward_rounded,
                        label: 'Receita',
                        color: AppColors.positive,
                      ),
                      _CommandLegend(
                        icon: Icons.show_chart_rounded,
                        label: 'Investir',
                        color: AppColors.brand,
                      ),
                      _CommandLegend(
                        icon: Icons.currency_bitcoin_rounded,
                        label: 'Cripto',
                        color: AppColors.crypto,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CommandLegend extends StatelessWidget {
  const _CommandLegend({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
    ],
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Align(
      alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        constraints: BoxConstraints(
          maxWidth: compact ? MediaQuery.sizeOf(context).width * 0.84 : 660,
        ),
        decoration: BoxDecoration(
          color: message.user
              ? const Color(0xFF59368F)
              : const Color(0xFF211C29),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.user ? 'Você' : 'Finance AI',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(message.text),
            if (message.action?['savedTransactionId'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Ação registrada · R\$ ${(message.action!['amount'] as num).toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(color: Color(0xFF6EE7B7)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
