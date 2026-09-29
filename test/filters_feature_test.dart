import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/filters/filters_feature.dart';

class _NoOff implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}

/// Catálogo controlável para exercitar o estado de erro.
class _FakeProducts implements ProductRepository {
  _FakeProducts([this.items = const []]);
  List<Product> items;
  Object? failure;

  @override
  Future<List<Product>> search(ProductQuery query) async {
    if (failure != null) throw failure!;
    return items;
  }

  @override
  Future<Product?> byBarcode(String barcode) async => null;
  @override
  Future<void> importProduct(Product product) async {}
}

AppScope _makeScope({ProductQuery? query, ProductRepository? products}) {
  final scope = AppScope(
    products: products ?? DemoProducts(),
    reviews: DemoReviews(),
    community: DemoCommunity(),
    openFoodFacts: _NoOff(),
    isDemo: true,
    userId: 'demo-user',
  );
  if (query != null) scope.query = query;
  return scope;
}

Future<void> _pump(WidgetTester tester, AppScope scope) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: NaTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: FiltersFeature(
            context: FeatureContext(scope: scope, openProduct: (_) {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Os filtros vêm recolhidos num ExpansionTile quando não há filtro ativo.
/// Abre a seção para interagir com os chips/estados internos.
Future<void> _expand(WidgetTester tester) async {
  final tile = find.byIcon(Icons.filter_alt_outlined);
  if (tile.evaluate().isNotEmpty) {
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('buildFilterQuery', () {
    test('combina marca e categoria preservando o texto', () {
      final q = buildFilterQuery(
        text: 'leite',
        brand: 'Campo Bom',
        category: 'Leite',
      );
      expect(q.text, 'leite');
      expect(q.brand, 'Campo Bom');
      expect(q.category, 'Leite');
    });

    test('sem marca nem categoria (limpar) mantém apenas o texto', () {
      final q = buildFilterQuery(text: 'leite');
      expect(q.text, 'leite');
      expect(q.brand, isNull);
      expect(q.category, isNull);
    });
  });

  group('extractFilterOptions', () {
    test('distinto, ordenado (case-insensitive) e ignora marca ausente', () {
      final options = extractFilterOptions(const [
        Product(barcode: '1', name: 'A', brand: 'Zeta', category: 'Doces'),
        Product(barcode: '2', name: 'B', brand: 'alfa', category: 'Doces'),
        Product(barcode: '3', name: 'C', category: 'Bebidas'), // sem marca
        Product(barcode: '4', name: 'D', brand: '   '), // marca em branco
        Product(barcode: '5', name: 'E', brand: 'Zeta'), // marca repetida
      ]);
      expect(options.brands, ['alfa', 'Zeta']);
      expect(options.categories, ['Bebidas', 'Doces']);
      expect(options.isEmpty, isFalse);
    });

    test('catálogo sem marca/categoria devolve opções vazias', () {
      final options = extractFilterOptions(const [
        Product(barcode: '1', name: 'Sem atributos'),
      ]);
      expect(options.isEmpty, isTrue);
    });
  });

  group('FiltersFeature', () {
    testWidgets('aplica marca e categoria mantendo o texto de busca', (
      tester,
    ) async {
      final scope = _makeScope(query: const ProductQuery(text: 'leite'));
      await _pump(tester, scope);
      await _expand(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Campo Bom'));
      await tester.pumpAndSettle();
      expect(scope.query.brand, 'Campo Bom');
      expect(scope.query.text, 'leite');
      await tester.tap(find.widgetWithText(FilterChip, 'Chocolate'));
      await tester.pumpAndSettle();
      expect(scope.query.category, 'Chocolate');
      expect(scope.query.brand, 'Campo Bom');
      expect(scope.query.text, 'leite');
      scope.dispose();
    });

    testWidgets('tocar de novo no mesmo filtro o remove', (tester) async {
      final scope = _makeScope();
      await _pump(tester, scope);
      await _expand(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Doce Serra'));
      await tester.pumpAndSettle();
      expect(scope.query.brand, 'Doce Serra');
      await tester.tap(find.widgetWithText(FilterChip, 'Doce Serra'));
      await tester.pumpAndSettle();
      expect(scope.query.brand, isNull);
      scope.dispose();
    });

    testWidgets('limpar zera marca e categoria preservando o texto', (
      tester,
    ) async {
      final scope = _makeScope(
        query: const ProductQuery(
          text: 'doce',
          brand: 'Campo Bom',
          category: 'Leite',
        ),
      );
      await _pump(tester, scope);
      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
      expect(scope.query.brand, isNull);
      expect(scope.query.category, isNull);
      expect(scope.query.text, 'doce');
      scope.dispose();
    });

    testWidgets('reflete a seleção atual vinda de scope.query', (tester) async {
      final scope = _makeScope(
        query: const ProductQuery(brand: 'Fazenda Aurora'),
      );
      await _pump(tester, scope);
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Fazenda Aurora'),
      );
      expect(chip.selected, isTrue);
      scope.dispose();
    });

    testWidgets('catálogo vazio mostra estado vazio', (tester) async {
      final scope = _makeScope(products: _FakeProducts());
      await _pump(tester, scope);
      await _expand(tester);
      expect(find.text('Nada para filtrar'), findsOneWidget);
      scope.dispose();
    });

    testWidgets('erro mostra mensagem segura e tenta novamente', (
      tester,
    ) async {
      final products = _FakeProducts(const [
        Product(barcode: '1', name: 'Suco', brand: 'Aurora', category: 'Suco'),
      ]);
      products.failure = const AppFailure(
        FailureKind.network,
        'Sem conexão. Tente novamente.',
      );
      final scope = _makeScope(products: products);
      await _pump(tester, scope);
      await _expand(tester);
      expect(find.text('Sem conexão. Tente novamente.'), findsOneWidget);
      products.failure = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Aurora'), findsOneWidget);
      scope.dispose();
    });
  });
}
