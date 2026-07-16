import 'dart:async';

import 'package:dio/dio.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:finance_ai/core/services/supabase_web_client.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _token;
  var _checking = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await SupabaseWebClient.instance.restoredSession();
    if (!mounted) return;
    setState(() {
      _token = token;
      _checking = false;
    });
  }

  Future<void> _signOut() async {
    await SupabaseWebClient.instance.signOut();
    if (mounted) setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!AppEnvironmentConfig.fromBuild().hasSupabaseConfiguration) {
      return const _ConfigurationRequiredPage();
    }
    if (_token != null) {
      return DashboardPreviewPage(onSignOut: _signOut);
    }
    return _AuthPage(
      onAuthenticated: (token) => setState(() => _token = token),
    );
  }
}

class _ConfigurationRequiredPage extends StatelessWidget {
  const _ConfigurationRequiredPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'A versão Web está sem a configuração pública do Supabase.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({required this.onAuthenticated});

  final ValueChanged<String> onAuthenticated;

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  Timer? _cooldownTimer;
  DateTime? _signupRetryAt;
  var _createAccount = false;
  var _loading = false;

  bool get _signupBlocked {
    final retryAt = _signupRetryAt;
    return retryAt != null && DateTime.now().isBefore(retryAt);
  }

  int get _cooldownSeconds {
    final retryAt = _signupRetryAt;
    if (retryAt == null) return 0;
    final seconds = retryAt.difference(DateTime.now()).inSeconds + 1;
    return seconds > 0 ? seconds : 0;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!_isValidEmail(email) || _password.text.length < 6) {
      _message(
        'Informe um e-mail válido e uma senha com pelo menos 6 caracteres.',
      );
      return;
    }
    if (_createAccount && _signupBlocked) {
      _message(
        'Aguarde ${_cooldownSeconds}s antes de pedir outro e-mail de confirmação.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = _createAccount
          ? await SupabaseWebClient.instance.signUp(email, _password.text)
          : await SupabaseWebClient.instance.signIn(email, _password.text);
      if (!mounted) return;
      if (result.accessToken != null) {
        widget.onAuthenticated(result.accessToken!);
        return;
      }
      _message(
        'Conta criada. Confira seu e-mail para confirmar a conta e depois entre.',
      );
      setState(() => _createAccount = false);
    } on DioException catch (error) {
      if (_createAccount && error.response?.statusCode == 429) {
        _startSignupCooldown(_retryAfter(error));
      }
      _message(_authError(error));
    } catch (_) {
      _message(
        'Não foi possível concluir a solicitação. Tente novamente em alguns minutos.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  Duration _retryAfter(DioException error) {
    final raw = error.response?.headers.value('retry-after');
    final seconds = int.tryParse(raw ?? '');
    if (seconds == null || seconds < 10) return const Duration(seconds: 60);
    return Duration(seconds: seconds > 900 ? 900 : seconds);
  }

  void _startSignupCooldown(Duration duration) {
    _cooldownTimer?.cancel();
    _signupRetryAt = DateTime.now().add(duration);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_signupBlocked) {
        timer.cancel();
        if (mounted) setState(() => _signupRetryAt = null);
        return;
      }
      setState(() {});
    });
    setState(() {});
  }

  String _authError(DioException error) {
    final statusCode = error.response?.statusCode;
    final payload = error.response?.data;
    final serverMessage = payload is Map
        ? payload['msg'] ?? payload['message']
        : null;

    if (statusCode == 429) {
      return 'O Supabase limitou temporariamente novos e-mails de confirmação. '
          'Não envie de novo agora; aguarde alguns minutos ou entre caso a conta já tenha sido confirmada.';
    }
    if (statusCode == 400 || statusCode == 422) {
      if (_createAccount &&
          '$serverMessage'.toLowerCase().contains('already')) {
        return 'Este e-mail já possui uma conta. Escolha “Já tenho uma conta” para entrar.';
      }
      return _createAccount
          ? 'Não foi possível criar a conta com estes dados. Revise o e-mail e a senha.'
          : 'E-mail ou senha inválidos. Se acabou de criar a conta, confirme o e-mail antes de entrar.';
    }
    return 'Não foi possível falar com o Supabase agora. Tente novamente.';
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  void _toggleMode() {
    _cooldownTimer?.cancel();
    setState(() {
      _signupRetryAt = null;
      _createAccount = !_createAccount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _createAccount && _signupBlocked;
    final submitLabel = _loading
        ? 'Aguarde...'
        : blocked
        ? 'Aguarde ${_cooldownSeconds}s'
        : _createAccount
        ? 'Criar conta'
        : 'Entrar';

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10072B), Color(0xFF061A3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: const Color(0xEE211C29),
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.auto_graph_rounded,
                        size: 48,
                        color: Color(0xFFC4B5FD),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _createAccount
                            ? 'Crie sua conta'
                            : 'Entre no Finance AI',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _createAccount
                            ? 'Seus dados financeiros ficam separados e protegidos por conta.'
                            : 'Acesse seu painel financeiro e dados sincronizados.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (_createAccount) ...[
                        const SizedBox(height: 18),
                        const _EmailConfirmationNotice(),
                      ],
                      const SizedBox(height: 26),
                      TextField(
                        controller: _email,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        autofillHints: const [AutofillHints.password],
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(labelText: 'Senha'),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading || blocked ? null : _submit,
                        child: Text(submitLabel),
                      ),
                      TextButton(
                        onPressed: _loading ? null : _toggleMode,
                        child: Text(
                          _createAccount
                              ? 'Já tenho uma conta'
                              : 'Criar uma conta',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailConfirmationNotice extends StatelessWidget {
  const _EmailConfirmationNotice();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF171D40),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF7166B5)),
    ),
    child: const Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined, color: Color(0xFFC4B5FD)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Após criar a conta, confirme o e-mail antes de entrar. Evite clicar novamente em “Criar conta” enquanto aguarda a mensagem.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    ),
  );
}
