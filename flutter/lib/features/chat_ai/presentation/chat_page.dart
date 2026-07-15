import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _messages = <String>[];
  bool _sending = false;
  String? _sessionId;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  String _idempotencyKey() {
    final random = Random.secure();
    String hex(int length) => List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-8${hex(3)}-${hex(12)}';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _messages.add('Você: $text'); _sending = true; });
    _controller.clear();
    try {
      final response = await Supabase.instance.client.functions.invoke('chat', body: {'message': text, 'sessionId': _sessionId, 'idempotencyKey': _idempotencyKey()});
      final data = response.data as Map<String, dynamic>;
      _sessionId = data['sessionId'] as String? ?? _sessionId;
      setState(() => _messages.add('Finance AI: ${data['action']}'));
    } on FunctionException catch (error) {
      setState(() => _messages.add('Erro seguro: ${error.details ?? error.reasonPhrase ?? 'não foi possível processar'}'));
    } catch (_) {
      setState(() => _messages.add('Conecte-se com sua conta do Finance AI para enviar comandos à IA. A tela continua disponível enquanto a conexão é preparada.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(child: _messages.isEmpty ? const Center(child: Text('Ex.: “Gastei 40 reais no mercado”')) : ListView.separated(padding: const EdgeInsets.all(20), itemCount: _messages.length, separatorBuilder: (_, index) => const SizedBox(height: 10), itemBuilder: (_, index) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_messages[index]))))),
        SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: TextField(controller: _controller, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Escreva uma movimentação ou pergunta'))), const SizedBox(width: 10), FilledButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Icons.send), label: const Text('Enviar'))]))),
      ]);
}
