import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/auth_repository.dart';
import '../../data/clients/app_failure.dart';

sealed class SessionState {
  const SessionState();
}

final class SessionInitializing extends SessionState {
  const SessionInitializing();
}

/// Sessão utilizável: visitante anônimo ou conta permanente.
sealed class SessionActive extends SessionState {
  const SessionActive(this.identity);
  factory SessionActive.of(AuthIdentity identity) =>
      identity.isAnonymous ? SessionGuest(identity) : SessionAccount(identity);
  final AuthIdentity identity;

  @override
  bool operator ==(Object other) =>
      other is SessionActive && other.identity == identity;
  @override
  int get hashCode => identity.hashCode;
}

final class SessionGuest extends SessionActive {
  const SessionGuest(super.identity);
}

final class SessionAccount extends SessionActive {
  const SessionAccount(super.identity);
}

/// Sem sessão utilizável. A recuperação é sempre explícita via [SessionController.retry].
final class SessionFailed extends SessionState {
  const SessionFailed(this.message, {this.expired = false});
  final String message;
  final bool expired;

  @override
  bool operator ==(Object other) =>
      other is SessionFailed &&
      other.message == message &&
      other.expired == expired;
  @override
  int get hashCode => Object.hash(message, expired);
}

/// Mantém o estado da sessão a partir dos eventos de auth.
///
/// Só notifica quando o estado muda: refresh de token e eventos repetidos do
/// mesmo usuário não reconstroem a navegação. Nunca cria sessão anônima
/// sozinho depois de uma saída, evitando loop de sessões.
class SessionController extends ChangeNotifier {
  SessionController(this._auth);
  final AuthRepository _auth;
  StreamSubscription<AuthChange>? _subscription;
  Future<void>? _signingIn;
  bool _disposed = false;

  SessionState _state = const SessionInitializing();
  SessionState get state => _state;

  String? get userId => switch (_state) {
    SessionActive(:final identity) => identity.userId,
    _ => null,
  };

  /// Chamar uma vez no bootstrap. Usa a sessão restaurada pelo SDK, mesmo sem
  /// rede; só pede sessão anônima quando não há nenhuma.
  Future<void> start() {
    // Erros do stream (ex.: sem rede) não apagam a identidade atual.
    _subscription ??= _auth.changes.listen(_onChange, onError: (Object _) {});
    return _adoptCurrentOrSignIn();
  }

  /// Recuperação explícita após erro ou sessão expirada.
  Future<void> retry() => _adoptCurrentOrSignIn();

  Future<void> _adoptCurrentOrSignIn() {
    final current = _auth.current;
    if (current != null) {
      _set(SessionActive.of(current));
      return Future.value();
    }
    // Chamadas concorrentes compartilham a mesma tentativa.
    return _signingIn ??= _signInAsGuest().whenComplete(
      () => _signingIn = null,
    );
  }

  Future<void> _signInAsGuest() async {
    _set(const SessionInitializing());
    try {
      final identity = await _auth.signInAnonymously();
      // Um evento de auth pode ter definido a sessão antes; ele prevalece.
      if (_state is SessionInitializing) _set(SessionActive.of(identity));
    } on AppFailure catch (failure) {
      _set(SessionFailed(failure.message));
    } catch (_) {
      _set(
        const SessionFailed(
          'Não foi possível iniciar sua sessão. Tente novamente.',
        ),
      );
    }
  }

  void _onChange(AuthChange change) {
    switch (change) {
      case AuthSignedIn(:final identity):
        _set(SessionActive.of(identity));
      case AuthSignedOut(expired: true):
        _set(
          const SessionFailed(
            'Sua sessão expirou. Toque em Tentar novamente para continuar.',
            expired: true,
          ),
        );
      case AuthSignedOut(expired: false):
        _set(
          const SessionFailed(
            'Você saiu da sua conta. Toque em Tentar novamente para continuar como visitante.',
          ),
        );
    }
  }

  void _set(SessionState next) {
    if (_disposed || next == _state) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
