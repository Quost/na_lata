import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:na_lata/data/auth_repository.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';

User user(String id, {bool anonymous = true}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
  isAnonymous: anonymous,
);

Session session(User user) =>
    Session(accessToken: 'token-secreto', tokenType: 'bearer', user: user);

SupabaseAuthRepository repository(MockClient http) {
  final sdk = SupabaseClient(
    'https://example.supabase.co',
    'public-test-key',
    httpClient: http,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(sdk.dispose);
  return SupabaseAuthRepository(BackendClient(sdk));
}

void main() {
  group('authChangeFrom', () {
    test(
      'login, refresh e atualização viram AuthSignedIn com a identidade',
      () {
        for (final event in [
          AuthChangeEvent.initialSession,
          AuthChangeEvent.signedIn,
          AuthChangeEvent.tokenRefreshed,
          AuthChangeEvent.userUpdated,
        ]) {
          final change = authChangeFrom(
            AuthState(event, session(user('u1', anonymous: false))),
          );
          expect(change, isA<AuthSignedIn>());
          expect(
            (change! as AuthSignedIn).identity,
            const AuthIdentity(userId: 'u1', isAnonymous: false),
          );
        }
      },
    );

    test('sessão inicial vazia é ignorada', () {
      expect(
        authChangeFrom(const AuthState(AuthChangeEvent.initialSession, null)),
        isNull,
      );
    });

    test('signedOut separa expiração de saída pedida', () {
      AuthChange? out(SignOutReason? reason) => authChangeFrom(
        AuthState(AuthChangeEvent.signedOut, null, signOutReason: reason),
      );
      expect(
        out(SignOutReason.sessionExpired),
        isA<AuthSignedOut>().having((c) => c.expired, 'expired', isTrue),
      );
      expect(
        out(SignOutReason.userInitiated),
        isA<AuthSignedOut>().having((c) => c.expired, 'expired', isFalse),
      );
    });
  });

  group('SupabaseAuthRepository', () {
    test('login anônimo devolve só id e tipo de conta', () async {
      final repo = repository(
        MockClient((request) async {
          expect(request.url.path, '/auth/v1/signup');
          return http.Response(
            '{"access_token":"token-secreto","token_type":"bearer",'
            '"expires_in":3600,"refresh_token":"refresh-secreto",'
            '"user":{"id":"u1","aud":"authenticated","is_anonymous":true,'
            '"app_metadata":{},"user_metadata":{},'
            '"created_at":"2026-01-01T00:00:00Z"}}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final identity = await repo.signInAnonymously();
      expect(identity, const AuthIdentity(userId: 'u1', isAnonymous: true));
      expect(repo.current, identity);
    });

    test('sem rede vira AppFailure de rede sem detalhes internos', () async {
      final repo = repository(
        MockClient((_) async => throw http.ClientException('detalhe interno')),
      );
      await expectLater(
        repo.signInAnonymously(),
        throwsA(
          isA<AppFailure>()
              .having((e) => e.kind, 'kind', FailureKind.network)
              .having((e) => e.message, 'message', isNot(contains('detalhe'))),
        ),
      );
      expect(repo.current, isNull);
    });
  });
}
