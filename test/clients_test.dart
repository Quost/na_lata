import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/clients/json_api_client.dart';
import 'package:na_lata/data/clients/app_failure.dart';

Matcher failure(FailureKind kind) =>
    isA<AppFailure>().having((e) => e.kind, 'kind', kind);
void main() {
  test(
    'Supabase usa transporte injetado e retorna dados da consulta',
    () async {
      final sdk = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/products');
          return http.Response(
            '[{"barcode":"12345678"}]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(sdk.dispose);
      final client = BackendClient(sdk);
      final rows = await client.request((db) => db.from('products').select());
      expect(rows.single['barcode'], '12345678');
      expect(
        () => client.requireUserId,
        throwsA(failure(FailureKind.unauthorized)),
      );
    },
  );
  test(
    'Supabase normaliza permissão/conflito e preserva erro de programação',
    () async {
      final sdk = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      );
      addTearDown(sdk.dispose);
      final client = BackendClient(sdk);
      for (final entry in [
        ('42501', FailureKind.unauthorized),
        ('23505', FailureKind.conflict),
        ('23514', FailureKind.validation),
      ]) {
        await expectLater(
          client.request<void>(
            (_) async => throw PostgrestException(
              message: 'detalhe privado',
              code: entry.$1,
            ),
          ),
          throwsA(failure(entry.$2)),
        );
      }
      await expectLater(
        client.request<void>((_) async => throw StateError('bug')),
        throwsStateError,
      );
    },
  );
  test('timeout não repete uma gravação', () async {
    final sdk = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    );
    addTearDown(sdk.dispose);
    final client = BackendClient(sdk, timeout: const Duration(milliseconds: 5));
    var calls = 0;
    final pending = Completer<void>();
    await expectLater(
      client.request<void>((_) {
        calls++;
        return pending.future;
      }),
      throwsA(failure(FailureKind.timeout)),
    );
    expect(calls, 1);
    pending.complete();
  });
  test('HTTP envia identificação e interpreta objeto JSON', () async {
    final api = JsonApiClient(
      transport: MockClient((request) async {
        expect(request.headers['User-Agent'], contains('NaLataClassroom'));
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('{"status":0}', 200);
      }),
    );
    addTearDown(api.close);
    expect(await api.getObject(Uri.https('example.org', '/product')), {
      'status': 0,
    });
  });
  test('HTTP rejeita JSON inválido e não repete 429', () async {
    var calls = 0;
    final api = JsonApiClient(
      transport: MockClient((_) async {
        calls++;
        return http.Response('private-body', 429);
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.getObject(Uri.https('example.org')),
      throwsA(failure(FailureKind.unavailable)),
    );
    expect(calls, 1);
    final malformed = JsonApiClient(
      transport: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(malformed.close);
    await expectLater(
      malformed.getObject(Uri.https('example.org')),
      throwsA(failure(FailureKind.invalidResponse)),
    );
  });
}
