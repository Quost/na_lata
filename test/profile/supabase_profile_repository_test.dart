import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/profile_repository.dart';
import 'package:na_lata/data/supabase_community.dart';
import 'package:na_lata/features/profile/profile_models.dart';

const userId = 'a1a1a1a1-1111-4111-8111-111111111111';
const otherId = 'b2b2b2b2-2222-4222-8222-222222222222';

Matcher failure(FailureKind kind, [String? message]) {
  var matcher = isA<AppFailure>().having((e) => e.kind, 'kind', kind);
  if (message != null) {
    matcher = matcher.having((e) => e.message, 'message', message);
  }
  return matcher;
}

http.Response json(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Cliente com transporte fake; [signedIn] recupera uma sessão local sem rede.
Future<BackendClient> backend(
  Future<http.Response> Function(http.Request) handler, {
  bool signedIn = true,
}) async {
  final sdk = SupabaseClient(
    'https://example.supabase.co',
    'public-test-key',
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    // O postgrest lê response.request; anexamos a requisição original.
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response(
        response.body,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  addTearDown(sdk.dispose);
  if (signedIn) {
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
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'email': 'privado@example.com',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-10-05T12:00:00Z',
        },
      }),
    );
  }
  return BackendClient(sdk);
}

Future<SupabaseProfileRepository> repository(
  Future<http.Response> Function(http.Request) handler, {
  bool signedIn = true,
}) async =>
    SupabaseProfileRepository(await backend(handler, signedIn: signedIn));

Map<String, dynamic> profileRow({String id = userId, String? bio}) => {
  'id': id,
  'nickname': 'Ana',
  'bio': bio,
};

void main() {
  test('byId lê outro usuário pedindo só colunas públicas', () async {
    final repo = await repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/profiles');
      expect(request.url.queryParameters['id'], 'eq.$otherId');
      expect(request.url.queryParameters['select'], 'id,nickname,bio');
      return json(profileRow(id: otherId, bio: 'Gosto de café'));
    });
    final profile = await repo.byId(otherId);
    expect(profile!.id, otherId);
    expect(profile.nickname, 'Ana');
    expect(profile.bio, 'Gosto de café');
  });

  test('byId inexistente devolve null e id vazio não consulta', () async {
    var calls = 0;
    final repo = await repository((_) async {
      calls++;
      return json(null);
    });
    expect(await repo.byId(otherId), isNull);
    expect(calls, 1);
    expect(await repo.byId('  '), isNull);
    expect(calls, 1);
  });

  test('erro do servidor não vira perfil inexistente', () async {
    final repo = await repository((_) async => json({}, status: 500));
    await expectLater(
      repo.byId(otherId),
      throwsA(failure(FailureKind.unavailable)),
    );
  });

  test('mine usa o id da sessão', () async {
    final repo = await repository((request) async {
      expect(request.url.queryParameters['id'], 'eq.$userId');
      return json(profileRow());
    });
    expect((await repo.mine()).id, userId);
  });

  test('mine sem linha de perfil é erro, não perfil vazio', () async {
    final repo = await repository((_) async => json(null));
    await expectLater(
      repo.mine(),
      throwsA(failure(FailureKind.unauthorized, profileNotFoundMessage)),
    );
  });

  test('updateMine grava só apelido e bio no perfil da sessão', () async {
    final repo = await repository((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.$userId');
      expect(request.url.queryParameters['select'], 'id,nickname,bio');
      expect(jsonDecode(request.body), {
        'nickname': 'Ana',
        'bio': 'Gosto de café',
      });
      return json([profileRow(bio: 'Gosto de café')]);
    });
    final saved = await repo.updateMine(
      const ProfileDraft(nickname: ' Ana ', bio: ' Gosto de café '),
    );
    expect(saved.bio, 'Gosto de café');
  });

  test('updateMine com bio vazia envia null', () async {
    final repo = await repository((request) async {
      expect(jsonDecode(request.body), {'nickname': 'Ana', 'bio': null});
      return json([profileRow()]);
    });
    expect(
      (await repo.updateMine(
        const ProfileDraft(nickname: 'Ana', bio: ' '),
      )).bio,
      isNull,
    );
  });

  test('updateMine com zero linhas não confirma sucesso', () async {
    final repo = await repository((_) async => json([]));
    await expectLater(
      repo.updateMine(const ProfileDraft(nickname: 'Ana')),
      throwsA(failure(FailureKind.unauthorized, profileNotFoundMessage)),
    );
  });

  test('validação falha antes de qualquer requisição', () async {
    var calls = 0;
    final repo = await repository((_) async {
      calls++;
      return json([]);
    });
    await expectLater(
      repo.updateMine(const ProfileDraft(nickname: 'a')),
      throwsA(failure(FailureKind.validation)),
    );
    await expectLater(
      repo.updateMine(ProfileDraft(nickname: 'Ana', bio: 'a' * 161)),
      throwsA(failure(FailureKind.validation)),
    );
    expect(calls, 0);
  });

  test('permissão negada pelo banco chega como unauthorized', () async {
    final repo = await repository(
      (_) async => json({
        'code': '42501',
        'message': 'permission denied for table profiles',
      }, status: 403),
    );
    await expectLater(
      repo.updateMine(const ProfileDraft(nickname: 'Ana')),
      throwsA(failure(FailureKind.unauthorized)),
    );
  });

  test('sem sessão não consulta nem grava', () async {
    var calls = 0;
    final repo = await repository((_) async {
      calls++;
      return json([]);
    }, signedIn: false);
    await expectLater(repo.mine(), throwsA(failure(FailureKind.unauthorized)));
    await expectLater(
      repo.updateMine(const ProfileDraft(nickname: 'Ana')),
      throwsA(failure(FailureKind.unauthorized)),
    );
    expect(calls, 0);
  });

  test('setNickname (T23) não depende de ler todas as colunas', () async {
    final client = await backend((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['select'], 'id');
      expect(jsonDecode(request.body), {'nickname': 'Ana'});
      return json([
        {'id': userId},
      ]);
    });
    await SupabaseCommunity(client).setNickname(' Ana ');
  });
}
