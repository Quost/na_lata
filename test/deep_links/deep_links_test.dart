import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/navigation/deep_links.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _profileId = '11111111-1111-4111-8111-111111111111';
const _listId = '22222222-2222-4222-8222-222222222222';

class _FakeContentSource implements DeepLinkContentSource {
  int calls = 0;
  Object? failure;
  Product? foundProduct = const Product(
    barcode: '000123456789',
    name: 'Produto compartilhado',
  );

  @override
  Future<Product?> product(String barcode) async {
    calls++;
    if (failure case final error?) throw error;
    return foundProduct?.barcode == barcode ? foundProduct : null;
  }

  @override
  Future<SharedProfile?> profile(String id) async {
    calls++;
    if (failure case final error?) throw error;
    return SharedProfile(id: id, nickname: 'Pessoa pública');
  }

  @override
  Future<SharedProductList?> list(String id) async {
    calls++;
    if (failure case final error?) throw error;
    return null;
  }
}

void main() {
  group('DeepLinkRoute', () {
    test('preserves leading zeros in product barcodes and generated URLs', () {
      const barcode = '000123456789';
      final uri = DeepLinkRoute.product(barcode);

      expect(uri.toString(), 'nalata://product/000123456789');
      expect(
        DeepLinkRoute.tryParse(uri.toString()),
        isA<ProductDeepLink>().having(
          (route) => route.barcode,
          'barcode',
          barcode,
        ),
      );
    });

    test('accepts profile/list UUIDs and normalizes case', () {
      expect(
        DeepLinkRoute.tryParse('nalata://profile/${_profileId.toUpperCase()}'),
        isA<ProfileDeepLink>().having((route) => route.id, 'id', _profileId),
      );
      expect(
        DeepLinkRoute.tryParse('nalata://list/$_listId'),
        isA<ListDeepLink>().having((route) => route.id, 'id', _listId),
      );
    });

    test('rejects malformed, private, and unsupported links', () {
      for (final value in [
        'not a uri',
        'https://example.org/product/000123456789',
        'nalata://product/1234',
        'nalata://product/000123456789/extra',
        'nalata://profile/not-a-uuid',
        'nalata://list/not-a-uuid',
        'nalata://product/000123456789?access_token=secret',
        'nalata://user@example.org/product/000123456789',
        'nalata://unknown/000123456789',
      ]) {
        expect(DeepLinkRoute.tryParse(value), isNull, reason: value);
      }
    });

    test('share URL builders reject invalid IDs before creating a link', () {
      expect(() => DeepLinkRoute.product('0000x'), throwsArgumentError);
      expect(() => DeepLinkRoute.profile('wrong'), throwsArgumentError);
      expect(() => DeepLinkRoute.list('wrong'), throwsArgumentError);
    });
  });

  group('DeepLinkResolver', () {
    test('validates UUID before invoking the data source', () async {
      final source = _FakeContentSource();
      final resolver = DeepLinkResolver(source);

      expect(await resolver.resolve('nalata://profile/invalid'), isNull);
      expect(await resolver.resolve('nalata://list/invalid'), isNull);
      expect(source.calls, 0);
    });

    test('resolves existing product/profile and missing list safely', () async {
      final source = _FakeContentSource();
      final resolver = DeepLinkResolver(source);

      final product = await resolver.resolve('nalata://product/000123456789');
      final profile = await resolver.resolve('nalata://profile/$_profileId');
      final missingList = await resolver.resolve('nalata://list/$_listId');

      expect(product, isA<ProductDestination>());
      expect((product! as ProductDestination).product.barcode, '000123456789');
      expect(
        (profile! as ProfileDestination).profile.nickname,
        'Pessoa pública',
      );
      expect(missingList, isNull);
    });

    test(
      'converts forbidden and unavailable results to an unavailable target',
      () async {
        for (final kind in [
          FailureKind.unauthorized,
          FailureKind.unavailable,
        ]) {
          final source = _FakeContentSource()
            ..failure = AppFailure(kind, 'private backend details');
          final destination = await DeepLinkResolver(
            source,
          ).resolve('nalata://list/$_listId');
          expect(destination, isNull);
        }
      },
    );

    test(
      'handles actual 403 and 404 profile responses without throwing',
      () async {
        for (final (status, code) in [(403, '42501'), (404, 'PGRST116')]) {
          final sdk = SupabaseClient(
            'https://example.supabase.co',
            'public-test-key',
            postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
            httpClient: MockClient((request) async {
              expect(request.url.path, '/rest/v1/profiles');
              return http.Response(
                jsonEncode({
                  'code': code,
                  'message': 'private server detail',
                  'details': '',
                  'hint': '',
                }),
                status,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }),
          );
          addTearDown(sdk.dispose);
          final source = RepositoryDeepLinkContentSource(
            products: DemoProducts(),
            profiles: SupabaseProfileRepository(BackendClient(sdk)),
          );

          expect(
            await DeepLinkResolver(
              source,
            ).resolve('nalata://profile/$_profileId'),
            isNull,
          );
        }
      },
    );
  });
}
