import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/app_scope.dart';
import '../../design_system/na_lata_ui.dart';
import '../appearance/theme_controller.dart';
import '../onboarding/onboarding_controller.dart';
import 'session_controller.dart';

/// Raiz do app: mostra o bootstrap da sessão e cria um [AppScope] por usuário.
///
/// Trocar de userId recria o escopo e o app inteiro (navegação, telas e
/// listeners), para que nada da conta anterior apareça. Refresh de token
/// mantém o mesmo userId e não reconstrói nada.
class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    required this.controller,
    required this.scopeFor,
    this.onboarding,
  });
  final SessionController controller;
  final AppScope Function(String userId) scopeFor;

  /// Primeiro uso; sobrevive à troca de usuário (é do aparelho, não da conta).
  final OnboardingController? onboarding;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  AppScope? _scope;

  @override
  void initState() {
    super.initState();
    _syncScope();
    widget.controller.addListener(_onSession);
  }

  void _onSession() => setState(_syncScope);

  void _syncScope() {
    final userId = widget.controller.userId;
    if (userId == null || userId == _scope?.userId) return;
    final previous = _scope;
    _scope = widget.scopeFor(userId);
    // Descarta depois do frame, quando as telas antigas já saíram da árvore.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSession);
    _scope?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (widget.controller.state) {
    SessionActive() => NaLataApp(
      key: ValueKey(_scope!.userId),
      scope: _scope!,
      onboarding: widget.onboarding,
    ),
    SessionInitializing() => const _BootstrapApp(
      child: NaLoading(label: 'Preparando sua sessão…'),
    ),
    SessionFailed(:final message, :final expired) => _BootstrapApp(
      child: NaEmpty(
        icon: expired ? Icons.lock_clock_outlined : Icons.error_outline,
        title: expired ? 'Sessão expirada' : 'Sessão não iniciada',
        message: message,
        action: OutlinedButton(
          onPressed: widget.controller.retry,
          child: const Text('Tentar novamente'),
        ),
      ),
    ),
  };
}

class _BootstrapApp extends StatelessWidget {
  const _BootstrapApp({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeController,
    builder: (context, mode, _) => MaterialApp(
      title: 'Na Lata',
      debugShowCheckedModeBanner: false,
      theme: NaTheme.light,
      darkTheme: NaTheme.dark,
      themeMode: mode,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(padding: NaSpace.page, child: child),
          ),
        ),
      ),
    ),
  );
}
