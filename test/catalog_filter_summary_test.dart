import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/app.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/catalog_query.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/catalog/catalog_feature.dart';
import 'package:na_lata/features/catalog/catalog_filter_summary.dart';
import 'package:na_lata/features/catalog/catalog_no_results.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppScope buildScope([ProductQuery? query]) {
  final scope = AppScope(
    products: DemoProducts(),
    reviews: DemoReviews(),
    community: DemoCommunity(),
    openFoodFacts: HttpOpenFoodFactsRepository(),
    isDemo: true,
    userId: 'user-a',
  );
  if (query != null) scope.query = query;
  return scope;
}

CatalogQuery fourFilters() => CatalogQuery(
  text: 'leite',
  brandKey: 'Fazenda Aurora',
  category: 'Leite',
  minRating: 4,
);

List<String> labels(List<NaFilterItem> items) => [
  for (final item in items) item.label,
];

/// Mostra o resumo ligado a uma consulta, como a tela faz.
class SummaryHarness extends StatelessWidget {
  const SummaryHarness({super.key, required this.query});
  final ValueNotifier<CatalogQuery> query;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CatalogQuery>(
    valueListenable: query,
    builder: (context, value, _) => NaFilterSummary(
      items: catalogFilterItems(value),
      onRemove: (id) => query.value = removeCatalogFilter(
        value,
        CatalogFilterKind.fromId(id),
      ),
      onClear: () => query.value = clearCatalogFilters(value),
    ),
  );
}

Widget app(Widget child, {double textScale = 1}) => MaterialApp(
  theme: NaTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void smallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('catalogFilterItems', () {
    test('consulta padrão não tem filtros', () {
      expect(catalogFilterItems(CatalogQuery()), isEmpty);
    });

    test('quatro filtros na ordem de exibição', () {
      expect(labels(catalogFilterItems(fourFilters())), [
        'Nome: “leite”',
        'Marca: fazenda aurora',
        'Categoria: Leite',
        'Nota mínima: 4 ou mais',
      ]);
    });

    test('cidade e UF viram um único chip de local', () {
      final items = catalogFilterItems(
        CatalogQuery(cityId: '4205407', uf: 'sc'),
      );
      expect(labels(items), ['Local: IBGE 4205407/SC']);
      expect(items.single.id, 'place');
    });

    test('só UF mostra a sigla e o nome do município substitui o código', () {
      expect(labels(catalogFilterItems(CatalogQuery(uf: 'SC'))), ['Local: SC']);
      final named = catalogFilterItems(
        CatalogQuery(cityId: '4205407', uf: 'SC'),
        cityName: (_) => 'Florianópolis',
      );
      expect(labels(named), ['Local: Florianópolis/SC']);
    });

    test('código de barras e período também aparecem', () {
      final items = catalogFilterItems(
        CatalogQuery(barcode: '0789123456', observedWithinDays: 30),
      );
      expect(labels(items), ['Código: 0789123456', 'Período: últimos 30 dias']);
      expect(labels(catalogFilterItems(CatalogQuery(observedWithinDays: 1))), [
        'Período: último dia',
      ]);
    });

    test('nome do botão de remover descreve a dimensão e o valor', () {
      final item = catalogFilterItems(fourFilters())[1];
      expect(item.removeLabel, 'Remover filtro de marca: fazenda aurora');
    });
  });

  group('remoção e limpeza', () {
    CatalogQuery full() => CatalogQuery(
      sort: CatalogSort.rating,
      text: 'leite',
      barcode: '0789123456',
      brandKey: 'Fazenda Aurora',
      category: 'Leite',
      cityId: '4205407',
      uf: 'SC',
      minRating: 4,
      observedWithinDays: 30,
    );

    for (final kind in CatalogFilterKind.values) {
      test('remover ${kind.name} conserva todos os outros filtros', () {
        final next = removeCatalogFilter(full(), kind);
        final ids = catalogFilterItems(next).map((item) => item.id).toSet();
        expect(
          ids,
          CatalogFilterKind.values.map((k) => k.name).toSet()
            ..remove(kind.name),
        );
        expect(next.sort, CatalogSort.rating);
      });
    }

    test('remover o local limpa cidade e UF juntas', () {
      final next = removeCatalogFilter(full(), CatalogFilterKind.place);
      expect(next.cityId, isNull);
      expect(next.uf, isNull);
      expect(next.text, 'leite');
    });

    test('limpar volta à consulta padrão, mantendo a ordenação', () {
      final next = clearCatalogFilters(full());
      expect(catalogFilterItems(next), isEmpty);
      expect(next, CatalogQuery(sort: CatalogSort.rating));
    });

    test('id desconhecido é rejeitado', () {
      expect(() => CatalogFilterKind.fromId('nada'), throwsArgumentError);
    });
  });

  group('ProductQuery', () {
    test('mostra nome, marca e categoria como o usuário escolheu', () {
      final items = productFilterItems(
        const ProductQuery(
          text: '  leite ',
          brand: 'Fazenda Aurora',
          category: 'Leite',
        ),
      );
      expect(labels(items), [
        'Nome: “leite”',
        'Marca: Fazenda Aurora',
        'Categoria: Leite',
      ]);
    });

    test('consulta vazia ou só com espaços não tem filtros', () {
      expect(productFilterItems(const ProductQuery()), isEmpty);
      expect(productFilterItems(const ProductQuery(text: '   ')), isEmpty);
    });

    test('remover um filtro conserva os outros', () {
      const query = ProductQuery(
        text: 'leite',
        brand: 'Doce Serra',
        category: 'X',
      );
      final noBrand = removeProductFilter(query, CatalogFilterKind.brand);
      expect(
        [noBrand.text, noBrand.brand, noBrand.category],
        ['leite', null, 'X'],
      );
      final noText = removeProductFilter(query, CatalogFilterKind.text);
      expect(
        [noText.text, noText.brand, noText.category],
        ['', 'Doce Serra', 'X'],
      );
      final noCategory = removeProductFilter(query, CatalogFilterKind.category);
      expect(
        [noCategory.text, noCategory.brand, noCategory.category],
        ['leite', 'Doce Serra', null],
      );
    });

    test('filtro que a consulta não tem não altera nada', () {
      const query = ProductQuery(text: 'leite', brand: 'Doce Serra');
      final next = removeProductFilter(query, CatalogFilterKind.minRating);
      expect([next.text, next.brand], ['leite', 'Doce Serra']);
    });
  });

  group('NaFilterSummary', () {
    testWidgets('sem filtros não mostra nada', (tester) async {
      final query = ValueNotifier(CatalogQuery());
      await tester.pumpWidget(app(SummaryHarness(query: query)));
      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('mostra quatro filtros como chips e a contagem', (
      tester,
    ) async {
      final query = ValueNotifier(fourFilters());
      await tester.pumpWidget(app(SummaryHarness(query: query)));
      expect(find.byType(InputChip), findsNWidgets(4));
      expect(find.text('4 filtros ativos'), findsOneWidget);
      expect(find.text('Nome: “leite”'), findsOneWidget);
      expect(find.text('Marca: fazenda aurora'), findsOneWidget);
      expect(find.text('Categoria: Leite'), findsOneWidget);
      expect(find.text('Nota mínima: 4 ou mais'), findsOneWidget);
    });

    testWidgets('remover um chip conserva os outros', (tester) async {
      final query = ValueNotifier(fourFilters());
      await tester.pumpWidget(app(SummaryHarness(query: query)));

      await tester.tap(
        find.byTooltip('Remover filtro de marca: fazenda aurora'),
      );
      await tester.pump();

      expect(find.byType(InputChip), findsNWidgets(3));
      expect(find.text('Marca: fazenda aurora'), findsNothing);
      expect(find.text('3 filtros ativos'), findsOneWidget);
      expect(query.value.brandKey, isNull);
      expect(
        [query.value.text, query.value.category, query.value.minRating],
        ['leite', 'Leite', 4],
      );
    });

    testWidgets('remove os filtros um a um até não sobrar nenhum', (
      tester,
    ) async {
      final query = ValueNotifier(fourFilters());
      await tester.pumpWidget(app(SummaryHarness(query: query)));
      for (final tooltip in [
        'Remover filtro de nome: “leite”',
        'Remover filtro de marca: fazenda aurora',
        'Remover filtro de categoria: Leite',
      ]) {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pump();
      }
      expect(find.text('1 filtro ativo'), findsOneWidget);
      expect(find.text('Nota mínima: 4 ou mais'), findsOneWidget);
      await tester.tap(
        find.byTooltip('Remover filtro de nota mínima: 4 ou mais'),
      );
      await tester.pump();
      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('Limpar filtros volta à consulta padrão', (tester) async {
      final query = ValueNotifier(fourFilters());
      await tester.pumpWidget(app(SummaryHarness(query: query)));

      await tester.tap(find.text('Limpar filtros'));
      await tester.pump();

      expect(find.byType(InputChip), findsNothing);
      expect(query.value, CatalogQuery());
    });

    testWidgets('cada remover tem rótulo e o resumo é anunciado', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final query = ValueNotifier(fourFilters());
      await tester.pumpWidget(app(SummaryHarness(query: query)));

      for (final tooltip in [
        'Remover filtro de nome: “leite”',
        'Remover filtro de marca: fazenda aurora',
        'Remover filtro de categoria: Leite',
        'Remover filtro de nota mínima: 4 ou mais',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
      }
      final announced = tester.getSemantics(find.text('4 filtros ativos'));
      expect(announced.label, contains('Marca: fazenda aurora'));
      expect(announced.label, contains('Nota mínima: 4 ou mais'));
      semantics.dispose();
    });

    testWidgets('quebra linha em 320 px com texto a 200% sem overflow', (
      tester,
    ) async {
      smallScreen(tester);
      final query = ValueNotifier(
        CatalogQuery(
          text: 'biscoito integral de aveia com mel e castanhas',
          brandKey: 'Fábrica de Alimentos Integrais Campo Bom e Região',
          category: 'Biscoitos e bolachas integrais sem adição de açúcar',
          cityId: '4205407',
          uf: 'SC',
          minRating: 5,
        ),
      );
      await tester.pumpWidget(app(SummaryHarness(query: query), textScale: 2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(InputChip), findsNWidgets(5));
      for (final chip in tester.widgetList(find.byType(InputChip))) {
        final rect = tester.getRect(find.byWidget(chip));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      expect(find.text('Limpar filtros'), findsOneWidget);
    });
  });

  group('CatalogFeature', () {
    Future<AppScope> pumpCatalog(
      WidgetTester tester,
      ProductQuery query,
    ) async {
      final scope = buildScope(query);
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        app(
          CatalogFeature(
            context: FeatureContext(scope: scope, openProduct: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return scope;
    }

    testWidgets('sem filtros não mostra o resumo', (tester) async {
      await pumpCatalog(tester, const ProductQuery());
      expect(find.byType(NaFilterSummary), findsNothing);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('mostra a consulta ativa como chips', (tester) async {
      await pumpCatalog(
        tester,
        const ProductQuery(
          text: 'leite',
          brand: 'Fazenda Aurora',
          category: 'Leite',
        ),
      );
      expect(find.byType(InputChip), findsNWidgets(3));
      expect(find.text('Marca: Fazenda Aurora'), findsOneWidget);
    });

    testWidgets('remover a marca conserva texto e categoria no escopo', (
      tester,
    ) async {
      final scope = await pumpCatalog(
        tester,
        const ProductQuery(
          text: 'leite',
          brand: 'Fazenda Aurora',
          category: 'Leite',
        ),
      );
      await tester.tap(
        find.byTooltip('Remover filtro de marca: Fazenda Aurora'),
      );
      await tester.pumpAndSettle();

      expect(scope.query.brand, isNull);
      expect(scope.query.text, 'leite');
      expect(scope.query.category, 'Leite');
      expect(find.byType(InputChip), findsNWidgets(2));
    });

    testWidgets('remover o nome limpa o campo de busca', (tester) async {
      final scope = await pumpCatalog(
        tester,
        const ProductQuery(text: 'leite', brand: 'Fazenda Aurora'),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'leite',
      );

      await tester.tap(find.byTooltip('Remover filtro de nome: “leite”'));
      await tester.pumpAndSettle();

      expect(scope.query.text, isEmpty);
      expect(scope.query.brand, 'Fazenda Aurora');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('Limpar filtros volta à consulta padrão e esvazia a busca', (
      tester,
    ) async {
      final scope = await pumpCatalog(
        tester,
        const ProductQuery(
          text: 'leite',
          brand: 'Fazenda Aurora',
          category: 'Leite',
        ),
      );
      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();

      expect(scope.query.text, isEmpty);
      expect(scope.query.brand, isNull);
      expect(scope.query.category, isNull);
      expect(find.byType(InputChip), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  });

  group('Nenhum resultado', () {
    testWidgets('informa a combinação ativa e oferece limpar', (tester) async {
      final scope = buildScope(
        const ProductQuery(text: 'leite', brand: 'Doce Serra'),
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(app(CatalogNoResults(scope: scope)));

      expect(find.text('Nenhum produto encontrado'), findsOneWidget);
      expect(
        find.textContaining('Nome: “leite” • Marca: Doce Serra'),
        findsOneWidget,
      );
      await tester.tap(find.text('Limpar filtros'));
      expect(scope.query.text, isEmpty);
      expect(scope.query.brand, isNull);
    });

    testWidgets('sem filtros diz que o catálogo está vazio', (tester) async {
      final scope = buildScope();
      addTearDown(scope.dispose);
      await tester.pumpWidget(app(CatalogNoResults(scope: scope)));

      expect(find.textContaining('O catálogo está vazio'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('cabe em 320 px com texto a 200% e o botão fica visível', (
      tester,
    ) async {
      smallScreen(tester);
      final scope = buildScope(
        const ProductQuery(
          text: 'biscoito integral de aveia com mel',
          brand: 'Fábrica de Alimentos Integrais Campo Bom',
          category: 'Biscoitos e bolachas integrais',
        ),
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        app(CatalogNoResults(scope: scope), textScale: 2),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Limpar filtros'), findsOneWidget);
    });

    testWidgets('na tela: busca sem resultado mostra a combinação e Limpar '
        'devolve o catálogo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // O ListView só constrói o que cabe na janela; aumenta para ver o fim.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scope = buildScope();
      addTearDown(scope.dispose);
      await tester.pumpWidget(NaLataApp(scope: scope));
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum produto encontrado'), findsOneWidget);
      expect(find.textContaining('Nome: “zzzz”'), findsWidgets);
      expect(find.text('Leite integral'), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Limpar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum produto encontrado'), findsNothing);
      expect(find.text('Leite integral'), findsOneWidget);
    });
  });
}
