import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/list_repository.dart';
import 'package:na_lata/features/lists/list_models.dart';

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
Future<SupabaseListRepository> repository(
  Future<http.Response> Function(http.Request) handler,
) async {
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
  return SupabaseListRepository(BackendClient(sdk));
}

Map<String, dynamic> listRow({String id = 'l1', int count = 0}) => {
  'id': id,
  'owner_id': userId,
  'name': 'Mercado',
  'description': null,
  'visibility': 'private',
  'created_at': '2026-10-05T12:00:00+00:00',
  'updated_at': '2026-10-05T12:00:00+00:00',
  'list_items': [
    {'count': count},
  ],
};

void main() {
  test('mine filtra pelo usuário da sessão e mapeia contagem', () async {
    final repo = await repository((request) async {
      expect(request.url.path, '/rest/v1/product_lists');
      expect(request.url.queryParameters['owner_id'], 'eq.$userId');
      expect(request.url.queryParameters['select'], contains('list_items'));
      return json([listRow(count: 2)]);
    });
    final lists = await repo.mine();
    expect(lists.single.itemCount, 2);
  });

  test('mine sem listas devolve vazio, não erro', () async {
    final repo = await repository((_) async => json([]));
    expect(await repo.mine(), isEmpty);
  });

  test('create envia owner_id da sessão e lista privada', () async {
    final repo = await repository((request) async {
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['owner_id'], userId);
      expect(body['name'], 'Mercado');
      expect(body['visibility'], 'private');
      expect(body.containsKey('id'), isFalse);
      return json(listRow(), status: 201);
    });
    final list = await repo.create(const ProductListDraft(name: ' Mercado '));
    expect(list.id, 'l1');
  });

  test('create de visitante recebe mensagem de conta confirmada', () async {
    final repo = await repository(
      (_) async => json({
        'code': '42501',
        'message': 'new row violates row-level security policy',
      }, status: 403),
    );
    await expectLater(
      repo.create(const ProductListDraft(name: 'Mercado')),
      throwsA(failure(FailureKind.unauthorized, accountRequiredMessage)),
    );
  });

  test('validação falha antes de qualquer requisição', () async {
    var calls = 0;
    final repo = await repository((_) async {
      calls++;
      return json([]);
    });
    await expectLater(
      repo.create(const ProductListDraft(name: '  ')),
      throwsA(failure(FailureKind.validation)),
    );
    expect(calls, 0);
  });

  test('update e delete com zero linhas não confirmam sucesso', () async {
    final repo = await repository((request) async {
      expect(request.url.queryParameters['owner_id'], 'eq.$userId');
      return json([]);
    });
    await expectLater(
      repo.update('l1', const ProductListDraft(name: 'Novo')),
      throwsA(failure(FailureKind.unavailable, listNotFoundMessage)),
    );
    await expectLater(
      repo.delete('l1'),
      throwsA(failure(FailureKind.unavailable, listNotFoundMessage)),
    );
  });

  test('addItem usa upsert que ignora duplicata', () async {
    final repo = await repository((request) async {
      expect(request.url.path, '/rest/v1/list_items');
      expect(request.url.queryParameters['on_conflict'], 'list_id,barcode');
      expect(request.headers['Prefer'], contains('ignore-duplicates'));
      expect(jsonDecode(request.body), {
        'list_id': 'l1',
        'barcode': '7891000100103',
      });
      return http.Response('', 201);
    });
    await repo.addItem('l1', ' 7891000100103 ');
  });

  test('removeItem informa se havia o produto', () async {
    var rows = <Object>[
      {'barcode': '7891000100103'},
    ];
    final repo = await repository((request) async {
      expect(request.method, 'DELETE');
      return json(rows);
    });
    expect(await repo.removeItem('l1', '7891000100103'), isTrue);
    rows = [];
    expect(await repo.removeItem('l1', '7891000100103'), isFalse);
  });

  test('items devolve barcodes e erro de rede não vira lista vazia', () async {
    final ok = await repository(
      (_) async => json([
        {'barcode': '1'},
        {'barcode': '2'},
      ]),
    );
    expect(await ok.items('l1'), ['1', '2']);

    final down = await repository((_) async => json({}, status: 500));
    await expectLater(
      down.items('l1'),
      throwsA(failure(FailureKind.unavailable)),
    );
  });
}
