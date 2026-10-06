import 'dart:convert';
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

  group('salvar conta (AUT02)', () {
    const userJson = {
      'id': 'u1',
      'aud': 'authenticated',
      'is_anonymous': true,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    };

    /// Repositório com sessão anônima de u1 já restaurada.
    Future<SupabaseAuthRepository> guest(
      http.Response Function(http.Request) handler,
    ) async {
      final sdk = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          final r = handler(request);
          return http.Response(
            r.body,
            r.statusCode,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
        // PKCE exige storage do supabase_flutter; no teste basta o implícito.
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      addTearDown(sdk.dispose);
      final expiresAt =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      await sdk.auth.recoverSession(
        jsonEncode({
          'access_token': 'header.payload.signature',
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': expiresAt,
          'refresh_token': 'refresh',
          'user': userJson,
        }),
      );
      return SupabaseAuthRepository(BackendClient(sdk));
    }

    http.Response error(int status, String code) => http.Response(
      jsonEncode({
        'code': status,
        'error_code': code,
        'msg': 'detalhe interno',
      }),
      status,
    );

    test('vincula email à mesma identidade e fica pendente', () async {
      final repo = await guest((request) {
        expect(request.method, 'PUT');
        expect(request.url.path, '/auth/v1/user');
        expect(request.url.queryParameters['redirect_to'], authCallbackUrl);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'ana@exemplo.com');
        expect(body.containsKey('password'), isFalse);
        return http.Response(
          jsonEncode({...userJson, 'new_email': 'ana@exemplo.com'}),
          200,
        );
      });
      await repo.linkEmail('ana@exemplo.com');
      expect(repo.pendingEmail, 'ana@exemplo.com');
      expect(repo.current, const AuthIdentity(userId: 'u1', isAnonymous: true));
    });

    test('email já usado e email inválido têm a mesma mensagem', () async {
      for (final (status, code, kind) in [
        (422, 'email_exists', FailureKind.conflict),
        (400, 'email_address_invalid', FailureKind.validation),
      ]) {
        final repo = await guest((_) => error(status, code));
        await expectLater(
          repo.linkEmail('ana@exemplo.com'),
          throwsA(
            isA<AppFailure>()
                .having((e) => e.kind, 'kind', kind)
                .having((e) => e.message, 'message', emailUnavailableMessage),
          ),
        );
        expect(repo.current!.isAnonymous, isTrue);
      }
    });

    test(
      'limite de envio vira aviso de espera, sem detalhes internos',
      () async {
        final repo = await guest(
          (_) => error(429, 'over_email_send_rate_limit'),
        );
        await expectLater(
          repo.resendConfirmation('ana@exemplo.com'),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.message,
              'message',
              allOf(contains('Muitas tentativas'), isNot(contains('detalhe'))),
            ),
          ),
        );
      },
    );
  });
}
