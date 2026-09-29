import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/compare/compare_feature.dart';

import 'fakes.dart';

void main() {
  late FakeCatalog catalog;
  late FakeReviews reviews;
  late AppScope scope;

  setUp(() {
    catalog = FakeCatalog([leite, chocolate, batata]);
    reviews = FakeReviews([
      review(leite.barcode, 5, 'a'),
      review(leite.barcode, 4, 'b'),
      review(chocolate.barcode, 2, 'a'),
    ]);
    scope = AppScope(
      products: catalog,
      reviews: reviews,
      community: DemoCommunity(),
      openFoodFacts: UnusedOpenFoodFacts(),
      isDemo: true,
      userId: 'demo-user',
    );
  });

  tearDown(() => scope.dispose());

  Future<void> pumpFeature(
    WidgetTester tester, {
    Product? product,
    RatingSummary Function(List<Review>) summarize = fakeSummarize,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CompareFeature(
              context: FeatureContext(
                scope: scope,
                product: product,
                openProduct: (_) {},
              ),
              summarize: summarize,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, int slot, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(slot));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('mostra marca, média, quantidade e distribuição lado a lado', (
    tester,
  ) async {
    await pumpFeature(tester);
    expect(find.text('Selecione dois produtos'), findsOneWidget);

    await choose(tester, 0, 'Leite integral · Fazenda Aurora');
    await choose(tester, 1, 'Chocolate ao leite · Doce Serra');

    for (final label in ['Marca', 'Média', 'Quantidade', 'Distribuição']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Fazenda Aurora'), findsOneWidget);
    expect(find.text('Doce Serra'), findsOneWidget);
    expect(find.text('4,5 de 5'), findsOneWidget);
    expect(find.text('2,0 de 5'), findsOneWidget);
    expect(find.text('2 avaliações'), findsOneWidget);
    expect(find.text('1 avaliação'), findsOneWidget);
    expect(find.text('5★: 1'), findsOneWidget);
    expect(find.text('2★: 1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(10));
    expect(find.text('Leite integral tem a maior média.'), findsOneWidget);
    expect(scope.comparison, {leite.barcode, chocolate.barcode});
  });

  testWidgets('recusa o mesmo produto nos dois lados', (tester) async {
    await pumpFeature(tester, product: leite);

    await choose(tester, 1, 'Leite integral · Fazenda Aurora');

    expect(
      find.text('Escolha um produto diferente do outro lado.'),
      findsOneWidget,
    );
    expect(find.text('Selecione dois produtos'), findsOneWidget);
    expect(reviews.queried, isEmpty);
    expect(scope.comparison, {leite.barcode});
  });

  testWidgets('produto sem marca e sem notas mostra textos de ausência', (
    tester,
  ) async {
    await pumpFeature(tester, product: leite);
    await choose(tester, 1, 'Batata palha');

    expect(find.text('Marca não informada'), findsOneWidget);
    expect(find.text('Sem avaliações'), findsOneWidget);
    expect(find.text('Nenhuma avaliação'), findsOneWidget);
    expect(find.text('Só Leite integral tem avaliações.'), findsOneWidget);
  });

  testWidgets('catálogo com menos de dois produtos mostra estado vazio', (
    tester,
  ) async {
    catalog.items = [leite];
    await pumpFeature(tester);

    expect(find.text('Produtos insuficientes'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('erro do catálogo mostra mensagem e permite tentar novamente', (
    tester,
  ) async {
    catalog.error = const AppFailure(FailureKind.timeout, 'Tempo esgotado.');
    await pumpFeature(tester);

    expect(find.text('Tempo esgotado.'), findsOneWidget);

    catalog.error = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
  });

  testWidgets('erro nas avaliações não vira comparação vazia', (tester) async {
    reviews.error = const AppFailure(FailureKind.network, 'Sem conexão.');
    scope.comparison.addAll([leite.barcode, chocolate.barcode]);
    await pumpFeature(tester);

    expect(find.text('Sem conexão.'), findsOneWidget);
    expect(find.text('Nenhuma avaliação'), findsNothing);
  });

  testWidgets('T10 pendente aparece como pendência, não como sucesso', (
    tester,
  ) async {
    scope.comparison.addAll([leite.barcode, chocolate.barcode]);
    await pumpFeature(
      tester,
      summarize: (_) => throw const FeaturePending('T10 — resumo de notas'),
    );

    expect(
      find.text('Entrega pendente: T10 — resumo de notas'),
      findsOneWidget,
    );
  });

  testWidgets('cabe em 320px com texto a 200%', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    scope.comparison.addAll([leite.barcode, chocolate.barcode]);
    await pumpFeature(tester);

    expect(find.text('Doce Serra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
