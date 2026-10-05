import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/json_api_client.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'fixtures.dart';

Matcher failure(FailureKind kind) =>
    isA<AppFailure>().having((e) => e.kind, 'kind', kind);

/// Corpo em UTF-8, como o OFF envia (marcas com acento).
http.Response jsonResponse(String body, int status) =>
    http.Response.bytes(utf8.encode(body), status);

void main() {
  late List<http.Request> requests;

  HttpOpenFoodFactsRepository repository(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final api = JsonApiClient(
      timeout: timeout,
      transport: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
    addTearDown(api.close);
    return HttpOpenFoodFactsRepository(api: api);
  }

  setUp(() => requests = []);

  test('consulta a API v2 com campos pedidos e converte o produto', () async {
    final off = repository((_) async => jsonResponse(offFound, 200));
    final product = await off.lookup('7891000100103');
    expect(product!.name, 'Leite Condensado Integral moça');
    expect(product.brand, 'nestlé');
    final url = requests.single.url;
    expect(url.scheme, 'https');
    expect(url.host, 'world.openfoodfacts.org');
    expect(url.path, '/api/v2/product/7891000100103.json');
    expect(url.queryParameters, {'fields': offFields});
  });

  test('preserva zeros à esquerda na URL e no produto', () async {
    final off = repository((_) async => jsonResponse(offNormalizedCode, 200));
    final product = await off.lookup('041196910759');
    expect(requests.single.url.path, '/api/v2/product/041196910759.json');
    expect(product!.barcode, '041196910759');
  });

  test('produto inexistente (HTTP 404 com status 0) retorna null', () async {
    final off = repository((_) async => jsonResponse(offNotFound, 404));
    expect(await off.lookup('7890000000017'), isNull);
  });

  test('404 sem corpo do OFF é resposta inválida, não inexistente', () async {
    final off = repository((_) async => jsonResponse('Not Found', 404));
    await expectLater(
      off.lookup('7890000000017'),
      throwsA(failure(FailureKind.invalidResponse)),
    );
  });

  test('429 e erro do servidor não viram inexistente nem repetem', () async {
    for (final status in [429, 500]) {
      requests.clear();
      final off = repository((_) async => jsonResponse('{"status":0}', status));
      await expectLater(
        off.lookup('7891000100103'),
        throwsA(failure(FailureKind.unavailable)),
      );
      expect(requests, hasLength(1));
    }
  });

  test('timeout e falha de rede são erros distintos', () async {
    final slow = repository(
      (_) => Future.delayed(
        const Duration(milliseconds: 50),
        () => jsonResponse(offFound, 200),
      ),
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      slow.lookup('7891000100103'),
      throwsA(failure(FailureKind.timeout)),
    );
    final offline = repository((_) async => throw http.ClientException('off'));
    await expectLater(
      offline.lookup('7891000100103'),
      throwsA(failure(FailureKind.network)),
    );
  });

  test('JSON inválido é erro de resposta', () async {
    final off = repository((_) async => jsonResponse('<html>', 200));
    await expectLater(
      off.lookup('7891000100103'),
      throwsA(failure(FailureKind.invalidResponse)),
    );
  });

  test('código inválido ou fictício não chega a fazer requisição', () async {
    final off = repository((_) async => jsonResponse(offFound, 200));
    for (final code in [
      '',
      '1234567',
      '123456789012345',
      ' 12345678',
      'demo-leite-1',
    ]) {
      await expectLater(
        off.lookup(code),
        throwsA(failure(FailureKind.validation)),
      );
    }
    expect(requests, isEmpty);
  });
}
