import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clients/app_failure.dart';
import 'clients/backend_client.dart';

/// Quem está usando o app. Guarda só id e tipo de conta; tokens ficam no SDK.
class AuthIdentity {
  const AuthIdentity({required this.userId, required this.isAnonymous});
  final String userId;
  final bool isAnonymous;

  @override
  bool operator ==(Object other) =>
      other is AuthIdentity &&
      other.userId == userId &&
      other.isAnonymous == isAnonymous;
  @override
  int get hashCode => Object.hash(userId, isAnonymous);
}

/// Evento de auth traduzido para o app, sem expor Session nem tokens.
sealed class AuthChange {
  const AuthChange();
}

/// Sessão válida: login, refresh de token ou atualização do usuário.
class AuthSignedIn extends AuthChange {
  const AuthSignedIn(this.identity);
  final AuthIdentity identity;
}

/// Sessão removida. [expired] separa expiração/sessão inválida de saída pedida.
class AuthSignedOut extends AuthChange {
  const AuthSignedOut({required this.expired});
  final bool expired;
}

abstract interface class AuthRepository {
  /// Sessão já restaurada pelo SDK (pode existir sem rede).
  AuthIdentity? get current;
  Stream<AuthChange> get changes;
  Future<AuthIdentity> signInAnonymously();
}

AuthIdentity identityOf(User user) =>
    AuthIdentity(userId: user.id, isAnonymous: user.isAnonymous);

/// Retorna null para eventos sem usuário (ex.: initialSession vazia).
AuthChange? authChangeFrom(AuthState state) {
  if (state.event == AuthChangeEvent.signedOut) {
    final reason = state.signOutReason;
    return AuthSignedOut(
      expired: reason != null && reason != SignOutReason.userInitiated,
    );
  }
  final user = state.session?.user;
  return user == null ? null : AuthSignedIn(identityOf(user));
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client);
  final BackendClient client;

  @override
  AuthIdentity? get current {
    final user = client.currentUser;
    return user == null ? null : identityOf(user);
  }

  /// Erros do stream (ex.: refresh sem rede) são ignorados para não apagar a
  /// identidade local; expiração real chega como signedOut.
  @override
  Stream<AuthChange> get changes => client.authChanges
      .handleError((Object _) {})
      .expand((state) => [?authChangeFrom(state)]);

  @override
  Future<AuthIdentity> signInAnonymously() async {
    final response = await client.request((db) => db.auth.signInAnonymously());
    final user = response.user;
    if (user == null) {
      throw const AppFailure(
        FailureKind.invalidResponse,
        'Não foi possível iniciar sua sessão. Tente novamente.',
      );
    }
    return identityOf(user);
  }
}

/// Modo demonstração: visitante fixo, sem eventos de auth.
class DemoAuthRepository implements AuthRepository {
  static const identity = AuthIdentity(userId: 'demo-user', isAnonymous: true);
  @override
  AuthIdentity get current => identity;
  @override
  Stream<AuthChange> get changes => const Stream.empty();
  @override
  Future<AuthIdentity> signInAnonymously() async => identity;
}
