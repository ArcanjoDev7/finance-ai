import 'package:dio/dio.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:finance_ai/core/services/supabase_web_client.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _token;
  var _checking = true;
  @override void initState() { super.initState(); SupabaseWebClient.instance.restoredSession().then((token) { if (mounted) setState(() { _token = token; _checking = false; }); }); }
  @override Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!AppEnvironmentConfig.fromBuild().hasSupabaseConfiguration) return const _ConfigurationRequiredPage();
    if (_token != null) return const DashboardPreviewPage();
    return _AuthPage(onAuthenticated: (token) => setState(() => _token = token));
  }
}

class _ConfigurationRequiredPage extends StatelessWidget { const _ConfigurationRequiredPage(); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('A versão Web está sem a configuração pública do Supabase.', textAlign: TextAlign.center)))); }

class _AuthPage extends StatefulWidget { const _AuthPage({required this.onAuthenticated}); final ValueChanged<String> onAuthenticated; @override State<_AuthPage> createState() => _AuthPageState(); }
class _AuthPageState extends State<_AuthPage> {
  final _email = TextEditingController(); final _password = TextEditingController(); var _createAccount = false; var _loading = false;
  @override void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.length < 6) { _message('Informe um e-mail válido e uma senha com pelo menos 6 caracteres.'); return; }
    setState(() => _loading = true);
    try {
      final result = _createAccount ? await SupabaseWebClient.instance.signUp(email, _password.text) : await SupabaseWebClient.instance.signIn(email, _password.text);
      if (!mounted) return;
      if (result.accessToken != null) { widget.onAuthenticated(result.accessToken!); return; }
      _message('Conta criada. Confira seu e-mail para confirmar a conta e depois entre.');
      setState(() => _createAccount = false);
    } on DioException catch (error) { _message(_authError(error)); }
    catch (_) { _message('Não foi possível concluir a solicitação. Tente novamente em alguns minutos.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  String _authError(DioException error) { final code = error.response?.statusCode; if (code == 429) return 'Muitas tentativas ou e-mails de confirmação enviados. Aguarde alguns minutos antes de tentar novamente.'; if (code == 400 || code == 422) return 'E-mail ou senha inválidos. Se acabou de criar a conta, confirme o e-mail antes de entrar.'; return 'Não foi possível falar com o Supabase agora. Tente novamente.'; }
  void _message(String value) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value))); }
  @override Widget build(BuildContext context) => Scaffold(body: DecoratedBox(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF10072B), Color(0xFF061A3A)], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Card(color: const Color(0xEE211C29), child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Icon(Icons.auto_graph_rounded, size: 48, color: Color(0xFFC4B5FD)), const SizedBox(height: 16), Text(_createAccount ? 'Crie sua conta' : 'Entre no Finance AI', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(_createAccount ? 'Seus dados financeiros ficam separados e protegidos por conta.' : 'Acesse seu painel financeiro e dados sincronizados.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)), const SizedBox(height: 26), TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')), const SizedBox(height: 12), TextField(controller: _password, obscureText: true, onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Senha')), const SizedBox(height: 20), FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Aguarde...' : (_createAccount ? 'Criar conta' : 'Entrar'))), TextButton(onPressed: _loading ? null : () => setState(() => _createAccount = !_createAccount), child: Text(_createAccount ? 'Já tenho uma conta' : 'Criar uma conta'))])))))));
}
