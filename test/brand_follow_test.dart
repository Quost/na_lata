import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/data/brand_repository.dart';
import 'package:na_lata/features/brands/brands_feature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _BrandFollows implements BrandFollowRepository {
  final Set<String> following = {};
  Completer<void>? pending;
  int calls = 0;

  @override
  Future<bool> isFollowing(String brandKey) async =>
      following.contains(brandKey);

  @override
  Future<List<String>> followingBrands() async => following.toList();

  @override
  Future<void> setFollowing({
    required String brandKey,
    required bool isFollowing,
  }) async {
    calls++;
    await pending?.future;
    if (isFollowing) {
      following.add(brandKey);
    } else {
      following.remove(brandKey);
    }
  }
}

AppScope _scope({
  required _BrandFollows follows,
  required bool isAuthenticated,
}) => AppScope(
  products: DemoProducts(),
  reviews: DemoReviews(),
  community: DemoCommunity(),
  brandFollows: follows,
  openFoodFacts: HttpOpenFoodFactsRepository(),
  isDemo: true,
  isAuthenticated: isAuthenticated,
  userId: 'demo-user',
);

void main() {
  test(
    'Supabase repository consulta e grava follows de forma idempotente',
    () async {
      const userId = '11111111-1111-4111-8111-111111111111';
      final token = _testJwt(userId);
      final requests = <http.Request>[];
      final sdk = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/signup') {
            return http.Response(
              jsonEncode({
                'access_token': token,
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'test-refresh-token',
                'user': {
                  'id': userId,
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'test@example.com',
                  'email_confirmed_at': DateTime.now()
                      .toUtc()
                      .toIso8601String(),
                  'app_metadata': {
                    'provider': 'email',
                    'providers': ['email'],
                  },
                  'user_metadata': {},
                  'identities': [],
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                  'is_anonymous': false,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          requests.add(request);
          if (request.method == 'GET') {
            final rows = request.url.queryParameters.containsKey('order')
                ? [
                    {'brand_key': 'brand-a'},
                    {'brand_key': 'brand-b'},
                  ]
                : [
                    {'brand_key': 'brand-a'},
                  ];
            return http.Response(
              jsonEncode(rows),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            '',
            request.method == 'POST' ? 201 : 204,
            request: request,
          );
        }),
      );
      addTearDown(sdk.dispose);
      await sdk.auth.signUp(email: 'test@example.com', password: 'password');
      final client = BackendClient(sdk);
      expect(client.isAuthenticated, isTrue);
      final repository = SupabaseBrandFollows(client);

      expect(await repository.isFollowing(' BRAND-A '), isTrue);
      expect(await repository.followingBrands(), ['brand-a', 'brand-b']);
      await repository.setFollowing(brandKey: ' BRAND-A ', isFollowing: true);
      await repository.setFollowing(brandKey: 'brand-a', isFollowing: true);
      await repository.setFollowing(brandKey: 'brand-a', isFollowing: false);

      final reads = requests
          .where((request) => request.method == 'GET')
          .toList();
      expect(reads, hasLength(2));
      expect(reads.first.url.queryParameters['brand_key'], 'eq.brand-a');
      expect(reads.first.url.queryParameters['user_id'], 'eq.$userId');
      final writes = requests
          .where((request) => request.method == 'POST')
          .toList();
      expect(writes, hasLength(2));
      for (final request in writes) {
        expect(request.url.queryParameters['on_conflict'], 'user_id,brand_key');
        expect(
          request.headers['prefer'],
          contains('resolution=ignore-duplicates'),
        );
        expect(jsonDecode(request.body), {
          'user_id': userId,
          'brand_key': 'brand-a',
        });
      }
      expect(
        requests
            .where((request) => request.method == 'DELETE')
            .single
            .url
            .queryParameters['user_id'],
        'eq.$userId',
      );
    },
  );

  test('brand repository valida a chave antes de acessar a sessão', () async {
    final sdk = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    );
    addTearDown(sdk.dispose);
    final client = BackendClient(sdk);
    expect(client.isAuthenticated, isFalse);
    final repository = SupabaseBrandFollows(client);

    await expectLater(
      repository.setFollowing(brandKey: '  ', isFollowing: true),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.kind,
          'kind',
          FailureKind.validation,
        ),
      ),
    );
    await expectLater(
      repository.isFollowing('valid-brand'),
      throwsA(isA<AppFailure>()),
    );
  });

  testWidgets('visitante recebe convite sem enviar gravação', (tester) async {
    final follows = _BrandFollows();
    final scope = _scope(follows: follows, isAuthenticated: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandsFeature(
            context: FeatureContext(scope: scope, openProduct: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazenda Aurora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguir marca'));
    await tester.pumpAndSettle();

    expect(find.text('Salve suas marcas favoritas'), findsOneWidget);
    expect(
      find.text(
        'Entre ou crie uma conta para seguir marcas e acompanhar novidades.',
      ),
      findsOneWidget,
    );
    expect(follows.following, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    scope.dispose();
  });

  testWidgets('falha reverte estado otimista e bloqueia toques repetidos', (
    tester,
  ) async {
    final follows = _BrandFollows()..pending = Completer<void>();
    final scope = _scope(follows: follows, isAuthenticated: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandsFeature(
            context: FeatureContext(scope: scope, openProduct: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazenda Aurora'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Seguir marca');
    await tester.tap(button);
    await tester.pump();
    expect(find.text('Seguindo'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    expect(follows.calls, 1);

    follows.pending!.completeError(StateError('private server detail'));
    await tester.pumpAndSettle();
    expect(find.text('Seguir marca'), findsOneWidget);
    expect(
      find.text('Não foi possível acessar as marcas. Tente novamente.'),
      findsOneWidget,
    );
    expect(follows.following, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    scope.dispose();
  });
}

String _testJwt(String userId) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': userId,
        'role': 'authenticated',
        'aud': 'authenticated',
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      }),
    ),
  );
  return '$header.$payload.test-signature';
}
