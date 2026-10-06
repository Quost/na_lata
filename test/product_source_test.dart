import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/core/product_source.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/data/supabase_products.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/detail/detail_feature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _fetchedAt = DateTime.utc(2026, 10, 5, 12, 30);
const _offUrl = 'https://world.openfoodfacts.org/product/7891000100103';

Product _offProduct({DateTime? fetchedAt}) => Product(
  barcode: '7891000100103',
  name: 'Leite condensado',
  source: ProductSource.openFoodFacts,
  sourceUrl: openFoodFactsProductUrl('7891000100103'),
  sourceFetchedAt: fetchedAt ?? _fetchedAt,
);

SupabaseClient _mockSupabase(
  Future<http.Response> Function(http.Request request) handler,
) {
  final sdk = SupabaseClient(
    'https://example.supabase.co',
    'public-test-key',
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    httpClient: MockClient(handler),
  );
  addTearDown(sdk.dispose);
  return sdk;
}

http.Response _json(Object body, http.Request request, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );

Widget _harness(Product product) {
  final scope = AppScope(
    products: DemoProducts(),
    reviews: DemoReviews(),
    community: DemoCommunity(),
    openFoodFacts: HttpOpenFoodFactsRepository(),
    isDemo: true,
    userId: 'demo-user',
  );
  addTearDown(scope.dispose);
  return MaterialApp(
    theme: NaTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: DetailFeature(
          context: FeatureContext(
            scope: scope,
            product: product,
            openProduct: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('safeSourceUri', () {
    test('aceita HTTPS em host permitido e subdomínios', () {
      expect(safeSourceUri(_offUrl), isNotNull);
      expect(safeSourceUri('https://openfoodfacts.org/'), isNotNull);
    });

    test('rejeita HTTP, host alheio, host parecido, credenciais e lixo', () {
      for (final raw in [
        null,
        '',
        'http://world.openfoodfacts.org/product/1',
        'https://evil.example.com/product/1',
        'https://openfoodfacts.org.evil.com/product/1',
        'https://notopenfoodfacts.org/product/1',
        'https://user:pass@world.openfoodfacts.org/product/1',
        'javascript:alert(1)',
        'ftp://world.openfoodfacts.org/x',
      ]) {
        expect(safeSourceUri(raw), isNull, reason: '$raw');
      }
    });
  });

  group('importação idempotente (Supabase)', () {
    test('envia metadados de origem em UTC com ignore-duplicates', () async {
      final sent = <http.Request>[];
      final sdk = _mockSupabase((request) async {
        sent.add(request);
        return _json(<Object>[], request, status: 201);
      });
      await SupabaseProducts(BackendClient(sdk)).importProduct(_offProduct());
      final request = sent.single;
      expect(request.url.path, '/rest/v1/products');
      expect(request.url.queryParameters['on_conflict'], 'barcode');
      expect(
        request.headers['Prefer'],
        contains('resolution=ignore-duplicates'),
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['source'], 'open_food_facts');
      expect(body['source_url'], _offUrl);
      expect(body['source_fetched_at'], '2026-10-05T12:30:00.000Z');
    });

    test('duas importações do mesmo barcode só tocam em products', () async {
      final sent = <http.Request>[];
      final sdk = _mockSupabase((request) async {
        sent.add(request);
        return _json(<Object>[], request, status: 201);
      });
      final repo = SupabaseProducts(BackendClient(sdk));
      await repo.importProduct(_offProduct());
      await repo.importProduct(_offProduct());
      expect(sent, hasLength(2));
      for (final request in sent) {
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/products');
        expect(request.headers['Prefer'], contains('ignore-duplicates'));
      }
    });

    test('linha antiga sem origem vira Product com origem nula', () async {
      final sdk = _mockSupabase(
        (request) async => _json([
          {
            'barcode': '7891000100103',
            'name': 'Antigo',
            'source': null,
            'source_url': null,
            'source_fetched_at': null,
          },
        ], request),
      );
      final product = await SupabaseProducts(
        BackendClient(sdk),
      ).byBarcode('7891000100103');
      expect(product!.source, isNull);
      expect(product.sourceUrl, isNull);
      expect(product.sourceFetchedAt, isNull);
    });

    test('linha com origem preserva fonte, link e data', () async {
      final sdk = _mockSupabase(
        (request) async => _json([
          {
            'barcode': '7891000100103',
            'name': 'Novo',
            'source': 'open_food_facts',
            'source_url': _offUrl,
            'source_fetched_at': '2026-10-05T12:30:00+00:00',
          },
        ], request),
      );
      final product = await SupabaseProducts(
        BackendClient(sdk),
      ).byBarcode('7891000100103');
      expect(product!.source, 'open_food_facts');
      expect(product.sourceFetchedAt, _fetchedAt);
    });
  });

  group('importação idempotente (demo)', () {
    test('reimportar não duplica, mantém a origem e as avaliações', () async {
      final products = DemoProducts();
      final reviews = DemoReviews();
      await products.importProduct(_offProduct());
      await reviews.save(
        const ReviewDraft(barcode: '7891000100103', rating: 4, comment: 'ok'),
      );
      await products.importProduct(_offProduct(fetchedAt: DateTime.utc(2027)));
      final found = await products.search(const ProductQuery(text: 'leite c'));
      expect(found, hasLength(1));
      expect(found.single.sourceFetchedAt, _fetchedAt);
      expect(await reviews.forProduct('7891000100103'), hasLength(1));
    });
  });

  group('ProductSourceInfo na ficha', () {
    testWidgets('produto do OFF mostra atribuição, data e link', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_offProduct()));
      expect(find.textContaining('Open Food Facts'), findsOneWidget);
      expect(find.textContaining('ODbL'), findsOneWidget);
      expect(find.text('Consultado em: 05/10/2026'), findsOneWidget);
      expect(find.text(_offUrl), findsOneWidget);
      expect(find.byTooltip('Copiar link da fonte'), findsOneWidget);
    });

    testWidgets('produto legado abre com origem não informada', (tester) async {
      await tester.pumpWidget(
        _harness(const Product(barcode: '7891000100103', name: 'Antigo')),
      );
      expect(find.text('Antigo'), findsOneWidget);
      expect(find.textContaining('Origem não informada'), findsOneWidget);
      expect(find.textContaining('Open Food Facts'), findsNothing);
      expect(find.textContaining('Consultado em'), findsNothing);
      expect(find.byTooltip('Copiar link da fonte'), findsNothing);
    });

    testWidgets('link com host ou protocolo inválido não é exibido', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          Product(
            barcode: '7891000100103',
            name: 'Suspeito',
            source: ProductSource.openFoodFacts,
            sourceUrl: 'http://evil.example.com/x',
            sourceFetchedAt: _fetchedAt,
          ),
        ),
      );
      expect(find.textContaining('evil.example.com'), findsNothing);
      expect(find.byTooltip('Copiar link da fonte'), findsNothing);
      expect(find.textContaining('Open Food Facts'), findsOneWidget);
    });
  });
}
