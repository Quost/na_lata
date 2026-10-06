import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/product_refresh_repository.dart';
import 'package:na_lata/data/supabase_products.dart';
import 'package:na_lata/features/detail/product_refresh.dart';

const userId = 'a1a1a1a1-1111-4111-8111-111111111111';
const barcode = '7891000100103';
const update = CatalogUpdate(
  barcode: barcode,
  name: ' Leite condensado integral ',
  brand: 'Moça',
  category: 'en:condensed-milks',
);

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

Map<String, dynamic> productRow() => {
  'barcode': barcode,
  'name': 'Leite condensado integral',
  'brand_key': 'moça',
  'category': 'en:condensed-milks',
  'image_url': null,
  'source': 'open_food_facts',
  'source_url': 'https://world.openfoodfacts.org/product/$barcode',
  'source_fetched_at': '2026-10-05T12:00:00+00:00',
};

/// Repositório com transporte fake; [signedIn] recupera sessão local sem rede.
Future<SupabaseProductRefresh> repository(
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
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-10-05T12:00:00Z',
        },
      }),
    );
  }
  final client = BackendClient(sdk);
  return SupabaseProductRefresh(client, SupabaseProducts(client));
}

void main() {
  test('chama a função só com campos de catálogo e relê a ficha', () async {
    final paths = <String>[];
    final repo = await repository((request) async {
      paths.add('${request.method} ${request.url.path}');
      if (request.url.path == '/rest/v1/rpc/refresh_product') {
        expect(jsonDecode(request.body), {
          'p_barcode': barcode,
          'p_name': 'Leite condensado integral',
          'p_brand_key': 'moça',
          'p_category': 'en:condensed-milks',
          'p_image_url': null,
        });
        return json([
          {'status': 'updated', 'retry_after_seconds': 0},
        ]);
      }
      expect(request.url.queryParameters['barcode'], 'eq.$barcode');
      return json([productRow()]);
    });

    final product = await repo.apply(update);

    expect(paths, [
      'POST /rest/v1/rpc/refresh_product',
      'GET /rest/v1/products',
    ]);
    expect(product.name, 'Leite condensado integral');
    expect(product.sourceFetchedAt, DateTime.utc(2026, 10, 5, 12));
  });

  test('unchanged devolve a ficha atual', () async {
    final repo = await repository(
      (request) async => request.url.path.endsWith('refresh_product')
          ? json([
              {'status': 'unchanged', 'retry_after_seconds': 0},
            ])
          : json([productRow()]),
    );
    expect((await repo.apply(update)).barcode, barcode);
  });

  test('rate_limited vira falha com o tempo que falta', () async {
    var calls = 0;
    final repo = await repository((_) async {
      calls++;
      return json([
        {'status': 'rate_limited', 'retry_after_seconds': 1500},
      ]);
    });
    await expectLater(
      repo.apply(update),
      throwsA(
        failure(
          FailureKind.unavailable,
          'Esta ficha foi atualizada há pouco. Tente de novo em 25 min.',
        ),
      ),
    );
    // Não relê a ficha nem tenta gravar de novo.
    expect(calls, 1);
  });

  test('not_found e ficha sumida na releitura são erro', () async {
    final missing = await repository(
      (_) async => json([
        {'status': 'not_found', 'retry_after_seconds': 0},
      ]),
    );
    await expectLater(
      missing.apply(update),
      throwsA(failure(FailureKind.unavailable, productGoneMessage)),
    );

    final gone = await repository(
      (request) async => request.url.path.endsWith('refresh_product')
          ? json([
              {'status': 'updated', 'retry_after_seconds': 0},
            ])
          : json([]),
    );
    await expectLater(
      gone.apply(update),
      throwsA(failure(FailureKind.unavailable, productGoneMessage)),
    );
  });

  test('resposta vazia ou status desconhecido é resposta inválida', () async {
    for (final body in [
      <Object>[],
      [
        {'status': 'deleted'},
      ],
    ]) {
      final repo = await repository((_) async => json(body));
      await expectLater(
        repo.apply(update),
        throwsA(failure(FailureKind.invalidResponse)),
      );
    }
  });

  test('campo recusado pelo banco chega como validação', () async {
    final repo = await repository(
      (_) async => json({
        'code': '23514',
        'message': 'Dados de catálogo inválidos.',
      }, status: 400),
    );
    await expectLater(
      repo.apply(update),
      throwsA(failure(FailureKind.validation)),
    );
  });

  test('erro do servidor não é repetido nem vira sucesso', () async {
    var calls = 0;
    final repo = await repository((_) async {
      calls++;
      return json({}, status: 500);
    });
    await expectLater(
      repo.apply(update),
      throwsA(failure(FailureKind.unavailable)),
    );
    expect(calls, 1);
  });

  test(
    'validação e falta de sessão falham antes de qualquer requisição',
    () async {
      var calls = 0;
      Future<http.Response> handler(http.Request _) async {
        calls++;
        return json([]);
      }

      final repo = await repository(handler);
      await expectLater(
        repo.apply(const CatalogUpdate(barcode: 'demo-leite-1', name: 'Leite')),
        throwsA(failure(FailureKind.validation)),
      );
      await expectLater(
        repo.apply(const CatalogUpdate(barcode: barcode, name: '  ')),
        throwsA(failure(FailureKind.validation)),
      );

      final anonymous = await repository(handler, signedIn: false);
      await expectLater(
        anonymous.apply(update),
        throwsA(failure(FailureKind.unauthorized)),
      );
      expect(calls, 0);
    },
  );
}
