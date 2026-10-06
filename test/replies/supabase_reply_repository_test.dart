import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/reply_repository.dart';
import 'package:na_lata/features/replies/reply_models.dart';

const userId = 'a1a1a1a1-1111-4111-8111-111111111111';

Matcher failure(FailureKind kind, [String? message]) {
  var matcher = isA<AppFailure>().having((e) => e.kind, 'kind', kind);
  if (message != null) {
    matcher = matcher.having((e) => e.message, 'message', message);
  }
  return matcher;
}

http.Response json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Repositório com sessão local (sem rede) e transporte fake.
Future<SupabaseReplyRepository> repository(
  Future<http.Response> Function(http.Request) handler,
) async {
  final sdk = SupabaseClient(
    'https://example.supabase.co',
    'public-test-key',
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
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
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-05T12:00:00Z',
      },
    }),
  );
  return SupabaseReplyRepository(BackendClient(sdk));
}

Map<String, dynamic> replyRow(String id, {String body = 'Concordo!'}) => {
  'id': id,
  'review_id': 'v1',
  'author_id': userId,
  'body': body,
  'created_at': '2026-10-05T12:00:00+00:00',
  'updated_at': '2026-10-05T12:00:00+00:00',
  'profiles': {'nickname': 'Ana'},
};

void main() {
   test('page filtra pela review e ordena por created_at e id', () async {
    final repo = await repository((request) async {
      expect(request.url.path, '/rest/v1/review_replies');
      expect(request.url.queryParameters['review_id'], 'eq.v1');
      final order = request.url.queryParameters['order']!;
      expect(order, startsWith('created_at.asc'));
      expect(order, contains(',id.asc'));
      expect(request.url.queryParameters['select'], contains('profiles'));
      return json([replyRow('r1')]);
    });
    final page = await repo.page('v1');
    expect(page.items.single.authorNickname, 'Ana');
    expect(page.hasMore, isFalse);
  });

  test('page pede uma linha a mais e descarta a sobra', () async {
    final repo = await repository((request) async {
      expect(request.url.queryParameters['offset'], '2');
      expect(request.url.queryParameters['limit'], '3');
      return json([replyRow('r3'), replyRow('r4'), replyRow('r5')]);
    });
    final page = await repo.page('v1', limit: 2, offset: 2);
    expect(page.items.map((r) => r.id), ['r3', 'r4']);
    expect(page.hasMore, isTrue);
  });

  test('page sem respostas devolve vazio, não erro', () async {
    final repo = await repository((_) async => json([]));
    final page = await repo.page('v1');
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('page rejeita limite e offset inválidos sem requisição', () async {
    var calls = 0;
    final repo = await repository((_) async {
      calls++;
      return json([]);
    });
    await expectLater(
      repo.page('v1', limit: 0),
      throwsA(failure(FailureKind.validation)),
    );
    await expectLater(
      repo.page('v1', offset: -1),
      throwsA(failure(FailureKind.validation)),
    );
    expect(calls, 0);
  });

  test('erro de servidor não vira lista vazia', () async {
    final repo = await repository((_) async => json({}, status: 500));
    await expectLater(
      repo.page('v1'),
      throwsA(failure(FailureKind.unavailable)),
    );
  });

  test('create envia author_id da sessão e o texto original', () async {
    final repo = await repository((request) async {
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {
        'review_id': 'v1',
        'author_id': userId,
        'body': '  Concordo!  ',
      });
      return json(replyRow('r1', body: '  Concordo!  '), status: 201);
    });
    final reply = await repo.create('v1', '  Concordo!  ');
    expect(reply.body, '  Concordo!  ');
  });

  test('create de visitante recebe mensagem de conta confirmada', () async {
    final repo = await repository(
      (_) async => json({
        'code': '42501',
        'message': 'new row violates row-level security policy',
      }, status: 403),
    );
    await expectLater(
      repo.create('v1', 'Oi'),
      throwsA(failure(FailureKind.unauthorized, replyAccountRequiredMessage)),
    );
  });

  test('create em review inexistente vira erro de validação', () async {
    final repo = await repository(
      (_) async => json({
        'code': '23503',
        'message': 'violates foreign key constraint',
      }, status: 409),
    );
    await expectLater(
      repo.create('inexistente', 'Oi'),
      throwsA(failure(FailureKind.validation)),
    );
  });

  test('texto inválido falha antes de qualquer requisição', () async {
    var calls = 0;
    final repo = await repository((_) async {
      calls++;
      return json([]);
    });
    await expectLater(
      repo.create('v1', '   '),
      throwsA(failure(FailureKind.validation)),
    );
    await expectLater(
      repo.update('r1', 'a' * 501),
      throwsA(failure(FailureKind.validation)),
    );
    expect(calls, 0);
  });

  test('update envia só o texto e filtra pelo autor da sessão', () async {
    final repo = await repository((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.r1');
      expect(request.url.queryParameters['author_id'], 'eq.$userId');
      expect(jsonDecode(request.body), {'body': 'Editado'});
      return json([replyRow('r1', body: 'Editado')]);
    });
    expect((await repo.update('r1', 'Editado')).body, 'Editado');
  });

  test('update e delete com zero linhas não confirmam sucesso', () async {
    final repo = await repository((request) async {
      expect(request.url.queryParameters['author_id'], 'eq.$userId');
      return json([]);
    });
    await expectLater(
      repo.update('r1', 'Novo'),
      throwsA(failure(FailureKind.unavailable, replyNotFoundMessage)),
    );
    await expectLater(
      repo.delete('r1'),
      throwsA(failure(FailureKind.unavailable, replyNotFoundMessage)),
    );
  });

  test('delete confirma quando apagou a resposta própria', () async {
    final repo = await repository((request) async {
      expect(request.method, 'DELETE');
      return json([
        {'id': 'r1'},
      ]);
    });
    await repo.delete('r1');
  });
}
