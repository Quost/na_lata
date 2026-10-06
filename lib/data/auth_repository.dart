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

  /// Email aguardando confirmação para salvar a conta, se houver.
  String? get pendingEmail;

  /// AUT02 — vincula o email à identidade anônima atual (mesmo userId) e
  /// envia o link de confirmação. Não cria nem mescla contas.
  Future<void> linkEmail(String email);
  Future<void> resendConfirmation(String email);

  /// Relê a sessão no servidor para saber se o email já foi confirmado.
  Future<AuthIdentity> reload();

  /// Define a senha da conta confirmada. O app não guarda a senha.
  Future<void> setPassword(String password);
}

/// Link do email de confirmação; precisa estar em Redirect URLs no Supabase
/// e no intent-filter do Android (ver docs/SUPABASE.md).
const authCallbackUrl = 'nalata://login-callback';

/// Mesma mensagem para email inválido e email já usado: não revela se existe
/// conta de outra pessoa com aquele endereço.
const emailUnavailableMessage =
    'Não foi possível usar este email. Confira o endereço ou use outro.';

/// Erro do Supabase Auth ao salvar conta, sem detalhes internos.
AppFailure accountFailure(AuthException error) {
  if (error is AuthRetryableFetchException) {
    return const AppFailure(
      FailureKind.network,
      'Sem conexão. Verifique sua internet.',
    );
  }
  return switch (error.code) {
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' => const AppFailure(
      FailureKind.unavailable,
      'Muitas tentativas. Aguarde alguns minutos e tente de novo.',
    ),
    'email_exists' ||
    'user_already_exists' ||
    'identity_already_exists' ||
    'email_conflict_identity_not_deletable' => const AppFailure(
      FailureKind.conflict,
      emailUnavailableMessage,
    ),
    'email_address_invalid' || 'validation_failed' => const AppFailure(
      FailureKind.validation,
      emailUnavailableMessage,
    ),
    'weak_password' => const AppFailure(
      FailureKind.validation,
      'Senha fraca. Use pelo menos 8 caracteres com letras e números.',
    ),
    'same_password' => const AppFailure(
      FailureKind.validation,
      'A nova senha precisa ser diferente da atual.',
    ),
    'session_not_found' ||
    'session_expired' ||
    'refresh_token_not_found' ||
    'refresh_token_already_used' => const AppFailure(
      FailureKind.unauthorized,
      'Sua sessão expirou. Reinicie o aplicativo.',
    ),
    _ => const AppFailure(
      FailureKind.unavailable,
      'Não foi possível salvar sua conta agora. Tente novamente.',
    ),
  };
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

  @override
  String? get pendingEmail => client.currentUser?.newEmail;

  @override
  Future<void> linkEmail(String email) => _account(
    (db) => db.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: authCallbackUrl,
    ),
  );

  @override
  Future<void> resendConfirmation(String email) => _account(
    (db) => db.auth.resend(
      type: OtpType.emailChange,
      email: email,
      emailRedirectTo: authCallbackUrl,
    ),
  );

  @override
  Future<AuthIdentity> reload() async {
    final response = await _account((db) => db.auth.refreshSession());
    final user = response.user;
    if (user == null) {
      throw const AppFailure(
        FailureKind.invalidResponse,
        'Não foi possível atualizar sua sessão. Tente novamente.',
      );
    }
    return identityOf(user);
  }

  @override
  Future<void> setPassword(String password) =>
      _account((db) => db.auth.updateUser(UserAttributes(password: password)));

  /// Erros de Auth viram mensagens de conta; timeout segue o BackendClient.
  Future<T> _account<T>(Future<T> Function(SupabaseClient db) action) =>
      client.request((db) async {
        try {
          return await action(db);
        } on AuthException catch (error) {
          throw accountFailure(error);
        }
      });
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

  static const _onlineOnly = AppFailure(
    FailureKind.unavailable,
    'Salvar conta só funciona no modo online.',
  );
  @override
  String? get pendingEmail => null;
  @override
  Future<void> linkEmail(String email) async => throw _onlineOnly;
  @override
  Future<void> resendConfirmation(String email) async => throw _onlineOnly;
  @override
  Future<AuthIdentity> reload() async => identity;
  @override
  Future<void> setPassword(String password) async => throw _onlineOnly;
}
