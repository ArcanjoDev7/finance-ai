import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppEnvironmentConfig.fromBuild().hasSupabaseConfiguration) {
      return const _ConfigurationRequiredPage();
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        return session == null ? const _SignInPage() : const DashboardPreviewPage();
      },
    );
  }
}

class _ConfigurationRequiredPage extends StatelessWidget {
  const _ConfigurationRequiredPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: const Card(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_off_outlined, size: 48), SizedBox(height: 16), Text('Conexão segura em configuração', style: TextStyle(fontSize: 22)), SizedBox(height: 10), Text('A versão Web precisa das variáveis públicas do Supabase para habilitar login e o assistente financeiro.', textAlign: TextAlign.center)]))),
          ),
        ),
      );
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _createAccount = false;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_createAccount) {
        await Supabase.instance.client.auth.signUp(email: _email.text.trim(), password: _password.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confira seu e-mail para confirmar a conta.')));
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
    } on AuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Icon(Icons.auto_awesome, size: 46), const SizedBox(height: 16), Text(_createAccount ? 'Crie sua conta' : 'Entre no Finance AI', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 24), TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')), const SizedBox(height: 12), TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')), const SizedBox(height: 20), FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Aguarde...' : (_createAccount ? 'Criar conta' : 'Entrar'))), TextButton(onPressed: _loading ? null : () => setState(() => _createAccount = !_createAccount), child: Text(_createAccount ? 'Já tenho uma conta' : 'Criar uma conta'))])),
          ),
        ),
      );
}
