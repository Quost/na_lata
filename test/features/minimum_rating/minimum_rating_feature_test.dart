import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/minimum_rating/minimum_rating_feature.dart';
import 'fakes.dart';

class _NoOff implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}

class _Harness {
  final reviews = FakeRatings(demoRatings());
  late final scope = AppScope(
    products: DemoProducts(),
    reviews: reviews,
    community: DemoCommunity(),
    openFoodFacts: _NoOff(),
    isDemo: true,
    userId: 'demo-user',
  );
  final opened = <Product>[];

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MinimumRatingFeature(
              context: FeatureContext(scope: scope, openProduct: opened.add),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

List<String> _listed(WidgetTester tester) => tester
    .widgetList<NaItemCard>(find.byType(NaItemCard))
    .map((c) => c.title)
    .toList();

Future<void> _choose(WidgetTester tester, int star) async {
  await tester.tap(find.byTooltip('Nota $star ou mais'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('padrão 4+ lista avaliados em ordem e abre o produto', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    expect(_listed(tester), [
      'Chocolate 70%',
      'Leite integral',
      'Chocolate ao leite',
    ]);
    expect(
      find.text('Fazenda Aurora • 4,5 de 5 · 2 avaliações'),
      findsOneWidget,
    );
    expect(find.text('Considerando todo o catálogo.'), findsOneWidget);
    await tester.tap(find.text('Leite integral'));
    expect(h.opened.single.barcode, 'demo-leite-1');
    h.scope.dispose();
  });

  testWidgets('trocar a nota filtra sem nova consulta', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final callsBefore = h.reviews.calls;
    await _choose(tester, 1);
    expect(_listed(tester), hasLength(5));
    expect(_listed(tester), isNot(contains('Batata palha tradicional')));
    await _choose(tester, 5);
    expect(_listed(tester), isEmpty);
    expect(find.text('Nenhum produto com nota 5 ou mais'), findsOneWidget);
    expect(h.reviews.calls, callsBefore);
    h.scope.dispose();
  });

  testWidgets('combina com a consulta do catálogo', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    h.scope.setQuery(const ProductQuery(brand: 'Fazenda Aurora'));
    await tester.pumpAndSettle();
    expect(_listed(tester), ['Chocolate 70%', 'Leite integral']);
    expect(find.text('Considerando marca Fazenda Aurora.'), findsOneWidget);
    h.scope.setQuery(
      const ProductQuery(text: 'leite', brand: 'Fazenda Aurora'),
    );
    await tester.pumpAndSettle();
    expect(_listed(tester), ['Leite integral']);
    h.scope.dispose();
  });

  testWidgets('refresh recarrega as notas', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _choose(tester, 5);
    expect(_listed(tester), isEmpty);
    h.reviews.ratings['demo-batata-1'] = [5];
    h.scope.refresh();
    await tester.pumpAndSettle();
    expect(_listed(tester), ['Batata palha tradicional']);
    h.scope.dispose();
  });

  testWidgets('tela de 320 px com texto em 200% não estoura o layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = _Harness();
    await h.pump(tester);
    await _choose(tester, 1);
    expect(tester.takeException(), isNull);
    expect(_listed(tester), hasLength(5));
    h.scope.dispose();
  });

  testWidgets('erro mostra mensagem segura e tenta novamente', (tester) async {
    final h = _Harness();
    h.reviews.failure = const AppFailure(
      FailureKind.network,
      'Sem conexão. Tente novamente.',
    );
    await h.pump(tester);
    expect(find.text('Sem conexão. Tente novamente.'), findsOneWidget);
    expect(_listed(tester), isEmpty);
    h.reviews.failure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(_listed(tester), hasLength(3));
    h.scope.dispose();
  });
}
