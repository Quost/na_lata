import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/compare/compare_feature.dart';
import 'package:na_lata/features/compare/unit_price_logic.dart';

import 'fakes.dart';

class FakeUnitPrices implements UnitPriceRepository {
  PackageQuantity? first = const PackageQuantity('500', QuantityUnit.g);
  PackageQuantity? second = const PackageQuantity('1', QuantityUnit.kg);
  bool missingPrice = false;
  Object? error;

  @override
  ComparisonWindow window(AppScope scope) => ComparisonWindow(
    from: DateTime.utc(2026, 9),
    until: DateTime.utc(2026, 10),
    cityId: '4208906',
    regionLabel: 'Jaraguá do Sul/SC',
  );

  @override
  Future<PackageQuantity?> quantity(Product product) async =>
      product.barcode == leite.barcode ? first : second;

  @override
  Future<List<PriceObservation>> observations(
    String barcode,
    ComparisonWindow window,
  ) async {
    if (error != null) throw error!;
    if (missingPrice) return [];
    final isFirst = barcode == leite.barcode;
    return [
      PriceObservation(
        id: barcode,
        barcode: barcode,
        cents: isFirst ? 1000 : 1500,
        cityId: '4208906',
        cityLabel: 'Jaraguá do Sul/SC',
        store: isFirst ? 'Loja A' : 'Loja B',
        observedAt: DateTime.utc(2026, 9, isFirst ? 10 : 20, 12),
      ),
    ];
  }
}

void main() {
  late AppScope scope;
  late FakeUnitPrices prices;

  setUp(() {
    prices = FakeUnitPrices();
    scope = AppScope(
      products: FakeCatalog([leite, chocolate]),
      reviews: FakeReviews([review(leite.barcode, 5)]),
      community: DemoCommunity(),
      openFoodFacts: UnusedOpenFoodFacts(),
      isDemo: true,
      userId: 'u',
    );
    scope.comparison.addAll([leite.barcode, chocolate.barcode]);
  });
  tearDown(() => scope.dispose());

  Future<void> pump(
    WidgetTester tester, {
    UnitPriceRepository? repository,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CompareFeature(
              context: FeatureContext(scope: scope, openProduct: (_) {}),
              summarize: fakeSummarize,
              unitPrices: repository ?? prices,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra fontes, datas, região, custo e preserva notas', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('R\$ 20,00/kg'), findsOneWidget);
    expect(find.text('R\$ 15,00/kg'), findsOneWidget);
    expect(find.textContaining('Loja A'), findsOneWidget);
    expect(find.textContaining('Loja B'), findsOneWidget);
    expect(find.textContaining('10/09/2026'), findsOneWidget);
    expect(find.textContaining('20/09/2026'), findsOneWidget);
    expect(
      find.text('Chocolate ao leite tem menor custo por kg.'),
      findsOneWidget,
    );
    expect(find.textContaining('não garantem oferta'), findsOneWidget);
    expect(find.text('5,0 de 5'), findsOneWidget);
  });

  testWidgets('massa vs volume não gera vencedor por custo', (tester) async {
    prices.second = const PackageQuantity('1', QuantityUnit.l);
    await pump(tester);
    expect(
      find.text('Sem vencedor por custo: massa e volume são incompatíveis.'),
      findsOneWidget,
    );
    expect(find.textContaining('tem menor custo'), findsNothing);
  });

  testWidgets('quantidade ausente e preço ausente ficam explícitos', (
    tester,
  ) async {
    prices.first = null;
    prices.missingPrice = true;
    await pump(tester);
    expect(find.text('Quantidade desconhecida'), findsOneWidget);
    expect(
      find.text('Sem preço válido na região e no período.'),
      findsNWidgets(2),
    );
    expect(find.textContaining('Sem vencedor por custo'), findsOneWidget);
  });

  testWidgets('erro de preços mantém notas e retry recupera', (tester) async {
    prices.error = const AppFailure(FailureKind.network, 'Sem conexão.');
    await pump(tester);
    expect(find.text('5,0 de 5'), findsOneWidget);
    expect(find.text('Sem conexão.'), findsOneWidget);
    prices.error = null;
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('R\$ 20,00/kg'), findsOneWidget);
  });

  testWidgets('integração pendente não é apresentada como ausência de preço', (
    tester,
  ) async {
    await pump(tester, repository: const PendingUnitPriceRepository());
    expect(find.textContaining('CAT03 (#89)'), findsOneWidget);
    expect(find.text('5,0 de 5'), findsOneWidget);
    expect(find.textContaining('Sem preço válido'), findsNothing);
  });

  testWidgets('320px e texto 200% exibem cartões sem overflow', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester);
    expect(find.text('R\$ 20,00/kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
