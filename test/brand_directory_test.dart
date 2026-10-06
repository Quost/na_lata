import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/brand_repository.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/features/brands/brand_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Products implements ProductRepository {
  _Products(this.items);
  final List<Product> items;
  @override
  Future<List<Product>> search(ProductQuery query) async => items;
  @override
  Future<Product?> byBarcode(String barcode) async => null;
  @override
  Future<void> importProduct(Product product) async {}
}

/// Falha na primeira chamada e depois delega.
class _FlakyBrands implements BrandRepository {
  _FlakyBrands(this.inner);
  final BrandRepository inner;
  var _failed = false;
  @override
  Future<BrandPage> search(String text, {String? after, int limit = 20}) {
    if (!_failed) {
      _failed = true;
      throw const AppFailure(FailureKind.network, 'Sem conexão.');
    }
    return inner.search(text, after: after, limit: limit);
  }
}

Product _p(String barcode, String? brand) =>
    Product(barcode: barcode, name: 'Produto $barcode', brand: brand);

final _products = [
  _p('1', null),
  _p('2', ''),
  _p('3', '   '),
  _p('4', 'nestlé'),
  _p('5', '  nestlé '),
  _p('6', 'nestle'),
  _p('7', 'NESTLÉ'),
  _p('8', 'campo bom'),
];

void main() {
  test('chave de pesquisa ignora bordas, caixa, espaços e acentos', () {
    expect(brandSearchKey('  Ação   Çaí NESTLÉ '), 'acao cai nestle');
  });

  group('DemoBrands', () {
    final brands = DemoBrands(_Products(_products));

    test('marca vazia não vira registro e produtos não duplicam', () async {
      final page = await brands.search('');
      expect(page.items.map((b) => b.key), [
        'NESTLÉ',
        'campo bom',
        'nestle',
        'nestlé',
      ]);
      expect(page.items.last.productCount, 2);
      expect(page.nextAfter, isNull);
    });

    test('busca ignora caixa e acento sem fundir marcas', () async {
      final page = await brands.search(' Nestle ');
      expect(page.items.map((b) => b.key), ['NESTLÉ', 'nestle', 'nestlé']);
    });

    test('pagina em duas páginas sem repetir', () async {
      final first = await brands.search('', limit: 3);
      expect(first.items, hasLength(3));
      expect(first.nextAfter, 'nestle');
      final second = await brands.search('', after: first.nextAfter, limit: 3);
      expect(second.items.map((b) => b.key), ['nestlé']);
      expect(second.nextAfter, isNull);
    });

    test('tamanho de página inválido é rejeitado', () {
      expect(() => brands.search('', limit: 0), throwsA(isA<AppFailure>()));
    });
  });

  group('SupabaseBrands', () {
    SupabaseBrands repository(http.Response Function(http.Request) reply) {
      final sdk = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
        httpClient: MockClient((request) async => reply(request)),
      );
      addTearDown(sdk.dispose);
      return SupabaseBrands(BackendClient(sdk));
    }

    http.Response json(Object body, http.Request request) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );

    test('chama search_brands no servidor e monta a página', () async {
      late Map<String, dynamic> params;
      final brands = repository((request) {
        expect(request.url.path, '/rest/v1/rpc/search_brands');
        params = jsonDecode(request.body) as Map<String, dynamic>;
        return json([
          {'brand': 'a', 'product_count': 2},
          {'brand': 'b', 'product_count': 1},
          {'brand': 'c', 'product_count': 1},
        ], request);
      });
      final page = await brands.search(' Nestlé ', after: 'x', limit: 2);
      expect(params, {'p_query': 'Nestlé', 'p_after': 'x', 'p_limit': 3});
      expect(page.items.map((b) => (b.key, b.productCount)), [
        ('a', 2),
        ('b', 1),
      ]);
      expect(page.nextAfter, 'b');
    });

    test('resposta inesperada vira erro tratado', () async {
      final brands = repository(
        (request) => json([
          {'brand': null},
        ], request),
      );
      expect(
        () => brands.search(''),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.kind,
            'kind',
            FailureKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('BrandSearch', () {
    Future<List<Brand>> pump(
      WidgetTester tester,
      BrandRepository repository, {
      int pageSize = 20,
    }) async {
      final selected = <Brand>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BrandSearch(
                repository: repository,
                pageSize: pageSize,
                onSelect: selected.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return selected;
    }

    testWidgets('busca, seleciona e mostra estado vazio', (tester) async {
      final selected = await pump(tester, DemoBrands(_Products(_products)));
      expect(find.text('campo bom'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'CAMPO');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('nestle'), findsNothing);
      await tester.tap(find.text('campo bom'));
      expect(selected.single.key, 'campo bom');
      expect(find.text('1 produto'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma marca encontrada'), findsOneWidget);
    });

    testWidgets('erro mostra mensagem e tentar novamente recarrega', (
      tester,
    ) async {
      final repository = _FlakyBrands(DemoBrands(_Products(_products)));
      await pump(tester, repository);
      expect(find.text('Sem conexão.'), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão.'), findsNothing);
      expect(find.text('campo bom'), findsOneWidget);
    });

    testWidgets('carrega a segunda página', (tester) async {
      await pump(tester, DemoBrands(_Products(_products)), pageSize: 3);
      expect(find.text('nestlé'), findsNothing);
      await tester.tap(find.text('Carregar mais marcas'));
      await tester.pumpAndSettle();
      expect(find.text('nestlé'), findsOneWidget);
      expect(find.text('Carregar mais marcas'), findsNothing);
    });
  });
}
