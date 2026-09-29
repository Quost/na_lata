import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/catalog/catalog_feature.dart';

AppScope makeScope({ProductQuery? query}) {
  final scope = AppScope(
    products: DemoProducts(),
    reviews: DemoReviews(),
    community: DemoCommunity(),
    openFoodFacts: HttpOpenFoodFactsRepository(),
    isDemo: true,
    userId: 'demo-user',
  );
  if (query != null) scope.query = query;
  return scope;
}

Future<void> pumpCatalog(WidgetTester tester, AppScope scope) =>
    tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CatalogFeature(
              context: FeatureContext(scope: scope, openProduct: (_) {}),
            ),
          ),
        ),
      ),
    );

void main() {
  group('buildSearchQuery', () {
    const current = ProductQuery(
      text: 'antigo',
      brand: 'Campo Bom',
      category: 'Leite',
    );

    test('aplica trim e mantém marca e categoria', () {
      final q = buildSearchQuery(current, '  leite  ');
      expect(q.text, 'leite');
      expect(q.brand, 'Campo Bom');
      expect(q.category, 'Leite');
    });

    test('texto vazio ou só espaços limpa apenas o texto', () {
      final q = buildSearchQuery(current, '   ');
      expect(q.text, '');
      expect(q.brand, 'Campo Bom');
      expect(q.category, 'Leite');
    });
  });

  group('CatalogFeature', () {
    testWidgets('submit atualiza scope.query.text', (tester) async {
      final scope = makeScope();
      await pumpCatalog(tester, scope);
      await tester.enterText(find.byType(TextField), 'leite');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(scope.query.text, 'leite');
      scope.dispose();
    });

    testWidgets('botão Buscar aplica o texto', (tester) async {
      final scope = makeScope();
      await pumpCatalog(tester, scope);
      await tester.enterText(find.byType(TextField), 'chocolate');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();
      expect(scope.query.text, 'chocolate');
      scope.dispose();
    });

    testWidgets('digitar sem confirmar não altera a query', (tester) async {
      final scope = makeScope();
      await pumpCatalog(tester, scope);
      await tester.enterText(find.byType(TextField), 'leit');
      await tester.pump();
      expect(scope.query.text, '');
      scope.dispose();
    });

    testWidgets('mantém marca e categoria ao buscar', (tester) async {
      final scope = makeScope(
        query: const ProductQuery(brand: 'Campo Bom', category: 'Leite'),
      );
      await pumpCatalog(tester, scope);
      await tester.enterText(find.byType(TextField), 'sem lactose');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();
      expect(scope.query.text, 'sem lactose');
      expect(scope.query.brand, 'Campo Bom');
      expect(scope.query.category, 'Leite');
      scope.dispose();
    });

    testWidgets('limpar zera o texto e mantém marca e categoria', (
      tester,
    ) async {
      final scope = makeScope(
        query: const ProductQuery(
          text: 'leite',
          brand: 'Campo Bom',
          category: 'Leite',
        ),
      );
      await pumpCatalog(tester, scope);
      expect(find.text('leite'), findsWidgets);
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pump();
      expect(scope.query.text, '');
      expect(scope.query.brand, 'Campo Bom');
      expect(scope.query.category, 'Leite');
      expect(find.byTooltip('Limpar busca'), findsNothing);
      scope.dispose();
    });

    testWidgets('busca vazia se comporta como limpar', (tester) async {
      final scope = makeScope(query: const ProductQuery(text: 'leite'));
      await pumpCatalog(tester, scope);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();
      expect(scope.query.text, '');
      scope.dispose();
    });

    testWidgets('reflete mudança de texto vinda de outro módulo', (
      tester,
    ) async {
      final scope = makeScope();
      await pumpCatalog(tester, scope);
      scope.setQuery(const ProductQuery(text: 'batata'));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'batata');
      scope.dispose();
    });
  });
}
