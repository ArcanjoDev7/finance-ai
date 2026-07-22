import 'dart:async';

import 'package:dio/dio.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:finance_ai/core/services/supabase_web_client.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _token;
  String? _recoveryToken;
  var _checking = true;
  Timer? _sessionSyncTimer;
  var _syncingSession = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
    _sessionSyncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _syncSessionAcrossTabs(),
    );
  }

  @override
  void dispose() {
    _sessionSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final recoveryToken = SupabaseWebClient.instance
        .recoveryAccessTokenFromCurrentUrl();
    if (recoveryToken != null) {
      await SupabaseWebClient.instance.clearStoredSession();
      if (!mounted) return;
      setState(() {
        _recoveryToken = recoveryToken;
        _token = null;
        _checking = false;
      });
      return;
    }
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

  void _finishRecovery() {
    setState(() => _recoveryToken = null);
    context.go('/');
  }

  Future<void> _syncSessionAcrossTabs() async {
    if (_checking || _syncingSession) return;
    _syncingSession = true;
    try {
      final storedToken = await SupabaseWebClient.instance.restoredSession();
      if (mounted && storedToken != _token) {
        setState(() => _token = storedToken);
      }
    } finally {
      _syncingSession = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!AppEnvironmentConfig.fromBuild().hasSupabaseConfiguration) {
      return const _ConfigurationRequiredPage();
    }
    if (_recoveryToken != null) {
      return _ResetPasswordPage(
        accessToken: _recoveryToken!,
        onFinished: _finishRecovery,
      );
    }
    if (_token != null) {
      return DashboardPreviewPage(
        key: ValueKey(_token),
        accessToken: _token!,
        onSignOut: _signOut,
      );
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

  Future<void> _requestPasswordReset() async {
    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      _message('Digite seu e-mail acima para receber o link de recuperação.');
      return;
    }
    setState(() => _loading = true);
    try {
      final redirectTo = Uri.base.replace(fragment: '', query: '').toString();
      await SupabaseWebClient.instance.requestPasswordReset(
        email,
        redirectTo: redirectTo,
      );
      _message(
        'Se esse e-mail estiver cadastrado, você receberá um link para criar uma nova senha.',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 429) {
        _message(
          'Muitas solicitações. Aguarde alguns minutos e tente novamente.',
        );
      } else {
        _message('Não foi possível enviar o link agora. Tente novamente.');
      }
    } catch (_) {
      _message('Não foi possível enviar o link agora. Tente novamente.');
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
    final compact = MediaQuery.sizeOf(context).width < 600;
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
            padding: EdgeInsets.all(compact ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: const Color(0xEE211C29),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 20 : 30),
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
                      if (!_createAccount)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _requestPasswordReset,
                            child: const Text('Esqueci minha senha'),
                          ),
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

class _ResetPasswordPage extends StatefulWidget {
  const _ResetPasswordPage({
    required this.accessToken,
    required this.onFinished,
  });

  final String accessToken;
  final VoidCallback onFinished;

  @override
  State<_ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<_ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _loading = false;
  var _completed = false;
  var _obscurePassword = true;
  var _obscureConfirmation = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 6) {
      _message('A nova senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (_password.text != _confirmation.text) {
      _message('As senhas digitadas não são iguais.');
      return;
    }
    setState(() => _loading = true);
    try {
      await SupabaseWebClient.instance.updatePassword(
        widget.accessToken,
        _password.text,
      );
      await SupabaseWebClient.instance.clearStoredSession();
      if (mounted) setState(() => _completed = true);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      _message(
        status == 401 || status == 403
            ? 'Este link expirou. Solicite um novo link na tela de login.'
            : 'Não foi possível alterar a senha. Solicite um novo link e tente novamente.',
      );
    } catch (_) {
      _message('Não foi possível alterar a senha agora. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
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
            padding: EdgeInsets.all(compact ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: const Color(0xEE211C29),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 20 : 30),
                  child: _completed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 54,
                              color: Color(0xFF3DD6A0),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Senha atualizada',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Agora você já pode entrar usando sua nova senha.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: widget.onFinished,
                              child: const Text('Voltar para o login'),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.lock_reset_rounded,
                              size: 50,
                              color: Color(0xFFC4B5FD),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Crie uma nova senha',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Escolha uma senha com pelo menos 6 caracteres.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 26),
                            TextField(
                              controller: _password,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Nova senha',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmation,
                              obscureText: _obscureConfirmation,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Confirmar nova senha',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureConfirmation =
                                        !_obscureConfirmation,
                                  ),
                                  icon: Icon(
                                    _obscureConfirmation
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: Text(
                                _loading ? 'Salvando...' : 'Salvar nova senha',
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
