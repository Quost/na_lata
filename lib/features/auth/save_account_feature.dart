import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/ui_format.dart';
import '../../data/auth_repository.dart';
import '../../design_system/na_lata_ui.dart';

const minPasswordLength = 8;
final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Email sem espaços nas bordas, ou null se o formato não parece de email.
String? validEmail(String raw) {
  final email = raw.trim();
  return _email.hasMatch(email) ? email : null;
}

/// AUT02 — transforma o visitante em conta com email e senha, mantendo o
/// mesmo userId (avaliações e favoritos continuam vinculados).
///
/// Fluxo do Supabase: 1) vincular email à sessão anônima e confirmar pelo
/// link; 2) com a conta confirmada, definir a senha. A senha só vai para o
/// Supabase; o app não a grava.
class SaveAccountFeature extends StatefulWidget {
  const SaveAccountFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<SaveAccountFeature> createState() => _SaveAccountFeatureState();
}

class _SaveAccountFeatureState extends State<SaveAccountFeature> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  StreamSubscription<AuthChange>? _changes;
  bool _editing = false;
  bool _busy = false;
  String? _error;
  String? _info;

  AuthRepository get _auth => widget.context.scope.auth;

  @override
  void initState() {
    super.initState();
    // Confirmação pelo link (deep link) chega como evento de auth.
    _changes = _auth.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Executa uma ação de conta. Erro mantém o formulário preenchido e a
  /// sessão de visitante; nada é reenviado automaticamente.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = messageForError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sendLink() {
    final email = validEmail(_emailController.text);
    if (email == null) {
      setState(() => _error = 'Digite um email válido.');
      return;
    }
    _run(() async {
      await _auth.linkEmail(email);
      if (!mounted) return;
      setState(() => _editing = false);
    });
  }

  void _resend(String email) => _run(() async {
    await _auth.resendConfirmation(email);
    if (mounted) setState(() => _info = 'Enviamos o link de novo.');
  });

  void _checkConfirmation() => _run(() async {
    final identity = await _auth.reload();
    if (identity.isAnonymous && mounted) {
      setState(
        () =>
            _info = 'Ainda não confirmado. Abra o link do email e volte aqui.',
      );
    }
  });

  void _savePassword() {
    final password = _passwordController.text;
    if (password.length < minPasswordLength) {
      setState(
        () => _error =
            'A senha precisa ter pelo menos $minPasswordLength caracteres.',
      );
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'As senhas não são iguais.');
      return;
    }
    _run(() async {
      await _auth.setPassword(password);
      _passwordController.clear();
      _confirmController.clear();
      if (!mounted) return;
      setState(() => _info = 'Senha salva. Sua conta está pronta.');
    });
  }

  void _cancel() => setState(() {
    _editing = false;
    _error = null;
    _info = null;
  });

  @override
  Widget build(BuildContext context) {
    final identity = _auth.current;
    if (identity == null) return const SizedBox.shrink();
    final pending = _auth.pendingEmail;
    return NaSection(
      title: 'Salvar minha conta',
      description: identity.isAnonymous
          ? 'Você está como visitante. Salve sua conta para recuperar '
                'avaliações e favoritos em outro aparelho.'
          : 'Sua conta está salva: avaliações e favoritos ficam com você.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!identity.isAnonymous)
            ..._passwordForm()
          else if (_editing || pending == null)
            ..._emailForm()
          else
            ..._pendingConfirmation(pending),
          if (_error != null) ...[
            const SizedBox(height: NaSpace.md),
            NaNotice(icon: Icons.error_outline, message: _error!),
          ],
          if (_info != null) ...[
            const SizedBox(height: NaSpace.md),
            NaNotice(message: _info!),
          ],
        ],
      ),
    );
  }

  List<Widget> _emailForm() {
    if (!_editing) {
      return [
        NaButton(
          label: 'Salvar minha conta',
          onPressed: () => setState(() => _editing = true),
        ),
      ];
    }
    return [
      TextField(
        controller: _emailController,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _sendLink(),
        decoration: const InputDecoration(
          labelText: 'Email',
          helperText: 'Enviaremos um link de confirmação.',
        ),
      ),
      const SizedBox(height: NaSpace.md),
      NaButton(
        label: 'Enviar confirmação',
        loading: _busy,
        onPressed: _sendLink,
      ),
      TextButton(
        onPressed: _busy ? null : _cancel,
        child: const Text('Cancelar'),
      ),
    ];
  }

  List<Widget> _pendingConfirmation(String email) => [
    NaNotice(
      icon: Icons.mark_email_unread_outlined,
      message:
          'Confirmação pendente: abra o link enviado para $email. '
          'Até lá você continua como visitante.',
    ),
    const SizedBox(height: NaSpace.md),
    NaButton(
      label: 'Já confirmei',
      loading: _busy,
      onPressed: _checkConfirmation,
    ),
    TextButton(
      onPressed: _busy ? null : () => _resend(email),
      child: const Text('Reenviar email'),
    ),
    TextButton(
      onPressed: _busy
          ? null
          : () => setState(() {
              _emailController.text = email;
              _editing = true;
            }),
      child: const Text('Usar outro email'),
    ),
  ];

  List<Widget> _passwordForm() => [
    TextField(
      controller: _passwordController,
      enabled: !_busy,
      obscureText: true,
      autofillHints: const [AutofillHints.newPassword],
      decoration: const InputDecoration(
        labelText: 'Senha',
        helperText: 'Pelo menos $minPasswordLength caracteres.',
      ),
    ),
    const SizedBox(height: NaSpace.md),
    TextField(
      controller: _confirmController,
      enabled: !_busy,
      obscureText: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _savePassword(),
      decoration: const InputDecoration(labelText: 'Repita a senha'),
    ),
    const SizedBox(height: NaSpace.md),
    NaButton(label: 'Salvar senha', loading: _busy, onPressed: _savePassword),
  ];
}
