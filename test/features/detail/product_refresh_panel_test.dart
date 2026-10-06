import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/product_refresh_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/detail/detail_feature.dart';
import 'package:na_lata/features/detail/product_refresh.dart';

const barcode = '7891000100103';

const current = Product(
  barcode: barcode,
  name: 'Leite condensado',
  brand: 'moça',
  category: 'en:condensed-milks',
);

const external = Product(
  barcode: barcode,
  name: 'Leite condensado integral',
  brand: 'moça',
  category: 'en:sweetened-condensed-milks',
);

/// Fonte externa fake: conta as consultas e responde o que o teste definir.
class _FakeOff implements OpenFoodFactsRepository {
  _FakeOff(this.answer);
  Future<Product?> Function() answer;
  var calls = 0;
  @override
  Future<Product?> lookup(String barcode) {
    calls++;
    return answer();
  }
}

/// Gravação fake: guarda o que foi pedido e devolve a ficha já alterada.
class _FakeRefresh implements ProductRefreshRepository {
  final applied = <CatalogUpdate>[];
  AppFailure? error;
  @override
  Future<Product> apply(CatalogUpdate update) async {
    applied.add(update);
    if (error != null) throw error!;
    return Product(
      barcode: update.barcode,
      name: update.name,
      brand: update.brand,
      category: update.category,
      imageUrl: update.imageUrl,
    );
  }
}

Future<({_FakeOff off, _FakeRefresh refresh, List<int> refreshes})> _pump(
  WidgetTester tester, {
  required Future<Product?> Function() answer,
  Product product = current,
  bool withRefresh = true,
}) async {
  final off = _FakeOff(answer);
  final refresh = _FakeRefresh();
  final scope = AppScope(
    products: DemoProducts(),
    reviews: DemoReviews(),
    community: DemoCommunity(),
    openFoodFacts: off,
    productRefresh: withRefresh ? refresh : null,
    isDemo: true,
    userId: 'demo-user',
  );
  addTearDown(scope.dispose);
  final refreshes = <int>[];
  scope.addListener(() => refreshes.add(1));
  await tester.pumpWidget(
    MaterialApp(
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
    ),
  );
  await tester.pumpAndSettle();
  return (off: off, refresh: refresh, refreshes: refreshes);
}

final _checkButton = find.text('Buscar atualização na fonte');
final _confirmButton = find.text('Confirmar atualização');

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('abrir a ficha não consulta a fonte', (tester) async {
    final fakes = await _pump(tester, answer: () async => external);
    expect(_checkButton, findsOneWidget);
    expect(fakes.off.calls, 0);
    expect(fakes.refresh.applied, isEmpty);
  });

  testWidgets('mostra antes/depois e só grava depois de confirmar', (
    tester,
  ) async {
    final fakes = await _pump(tester, answer: () async => external);
    await _tap(tester, _checkButton);

    expect(find.text('O que vai mudar'), findsOneWidget);
    expect(find.text('Antes: Leite condensado'), findsOneWidget);
    expect(find.text('Depois: Leite condensado integral'), findsOneWidget);
    expect(find.text('Antes: en:condensed-milks'), findsOneWidget);
    expect(find.text('Depois: en:sweetened-condensed-milks'), findsOneWidget);
    // Marca não mudou e não aparece na comparação.
    expect(find.text('Marca'), findsNothing);
    expect(fakes.refresh.applied, isEmpty);
    expect(find.text('Categoria: en:condensed-milks'), findsOneWidget);

    await _tap(tester, _confirmButton);

    expect(fakes.refresh.applied, hasLength(1));
    expect(fakes.refresh.applied.single.name, 'Leite condensado integral');
    expect(fakes.off.calls, 1);
    expect(
      find.text('Ficha atualizada com os dados da fonte.'),
      findsOneWidget,
    );
    expect(find.text('Leite condensado integral'), findsOneWidget);
    expect(
      find.text('Categoria: en:sweetened-condensed-milks'),
      findsOneWidget,
    );
    expect(fakes.refreshes, hasLength(1));
  });

  testWidgets('cancelar não grava e mantém a ficha', (tester) async {
    final fakes = await _pump(tester, answer: () async => external);
    await _tap(tester, _checkButton);
    await _tap(tester, find.text('Cancelar'));

    expect(fakes.refresh.applied, isEmpty);
    expect(find.text('Atualização cancelada. Nada foi alterado.'), findsOne);
    expect(find.text('Leite condensado'), findsOneWidget);
    expect(_checkButton, findsOneWidget);
  });

  testWidgets('sem mudança na fonte informa e não grava', (tester) async {
    final fakes = await _pump(tester, answer: () async => current);
    await _tap(tester, _checkButton);

    expect(find.text('A ficha já está atualizada com a fonte.'), findsOne);
    expect(_confirmButton, findsNothing);
    expect(fakes.refresh.applied, isEmpty);
    expect(fakes.refreshes, isEmpty);
  });

  testWidgets('produto ausente na fonte (404) preserva a ficha', (
    tester,
  ) async {
    final fakes = await _pump(tester, answer: () async => null);
    await _tap(tester, _checkButton);

    expect(
      find.textContaining('A fonte não tem mais este produto.'),
      findsOneWidget,
    );
    expect(find.text('Leite condensado'), findsOneWidget);
    expect(fakes.refresh.applied, isEmpty);
  });

  testWidgets('429 preserva a ficha e não repete a consulta', (tester) async {
    final fakes = await _pump(
      tester,
      answer: () async => throw const AppFailure(
        FailureKind.unavailable,
        'Muitas consultas. Aguarde antes de tentar novamente.',
      ),
    );
    await _tap(tester, _checkButton);

    expect(
      find.text(
        'Muitas consultas. Aguarde antes de tentar novamente. '
        'A ficha foi mantida como estava.',
      ),
      findsOneWidget,
    );
    expect(fakes.off.calls, 1);
    expect(fakes.refresh.applied, isEmpty);
    expect(find.text('Leite condensado'), findsOneWidget);
    expect(_checkButton, findsOneWidget);
  });

  testWidgets('erro inesperado não expõe detalhes', (tester) async {
    await _pump(tester, answer: () async => throw Exception('token=segredo'));
    await _tap(tester, _checkButton);

    expect(find.textContaining('segredo'), findsNothing);
    expect(
      find.textContaining('Não foi possível consultar a fonte.'),
      findsOneWidget,
    );
  });

  testWidgets('gravação recusada pelo limite mantém a ficha anterior', (
    tester,
  ) async {
    final fakes = await _pump(tester, answer: () async => external);
    fakes.refresh.error = refreshRateLimited(const Duration(minutes: 20));
    await _tap(tester, _checkButton);
    await _tap(tester, _confirmButton);

    expect(fakes.refresh.applied, hasLength(1));
    expect(
      find.textContaining('Esta ficha foi atualizada há pouco.'),
      findsOneWidget,
    );
    expect(find.text('Leite condensado'), findsOneWidget);
    expect(find.text('Categoria: en:condensed-milks'), findsOneWidget);
    expect(fakes.refreshes, isEmpty);
  });

  testWidgets('produto de demonstração não oferece atualização', (
    tester,
  ) async {
    await _pump(
      tester,
      answer: () async => external,
      product: demoProducts.first,
    );
    expect(_checkButton, findsNothing);
  });

  testWidgets('sem repositório injetado a ação fica indisponível', (
    tester,
  ) async {
    await _pump(tester, answer: () async => external, withRefresh: false);
    expect(_checkButton, findsNothing);
    expect(find.text('Leite condensado'), findsOneWidget);
  });

  testWidgets('cabe em 320 px com texto em 200%', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await _pump(tester, answer: () async => external);
    await _tap(tester, _checkButton);

    expect(_confirmButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
