import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/barcode/barcode_feature.dart';

import 'fakes.dart';

void main() {
  late FakeProducts products;
  late FakeOpenFoodFacts off;
  late AppScope scope;
  late List<Product> opened;
  late int refreshes;

  setUp(() {
    products = FakeProducts();
    off = FakeOpenFoodFacts();
    opened = [];
    refreshes = 0;
    scope = AppScope(
      products: products,
      reviews: DemoReviews(),
      community: DemoCommunity(),
      openFoodFacts: off,
      isDemo: true,
      userId: 'demo-user',
    )..addListener(() => refreshes++);
  });

  tearDown(() => scope.dispose());

  Future<void> pumpFeature(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: NaTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: BarcodeFeature(
            context: FeatureContext(scope: scope, openProduct: opened.add),
          ),
        ),
      ),
    ),
  );

  Future<void> submit(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextFormField), code);
    await tester.tap(find.text('Consultar'));
    await tester.pump();
  }

  testWidgets('cabe em 320px com texto a 200% no estado de ausência', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpFeature(tester);
    await submit(tester, '00000000');
    await tester.pumpAndSettle();

    expect(find.text('Produto não encontrado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('campo vazio mostra validação e não consulta', (tester) async {
    await pumpFeature(tester);
    await submit(tester, '');

    expect(find.text('Digite o código de barras.'), findsOneWidget);
    expect(products.lookups, isEmpty);
    expect(off.lookups, isEmpty);
  });

  testWidgets('código curto é rejeitado; letras são filtradas', (tester) async {
    await pumpFeature(tester);
    await submit(tester, '12ab34');

    expect(find.textContaining('você digitou 4'), findsOneWidget);
    expect(off.lookups, isEmpty);
  });

  testWidgets('encontrado no catálogo abre a ficha preservando zeros', (
    tester,
  ) async {
    products.items.add(const Product(barcode: '00012345', name: 'Biscoito'));
    await pumpFeature(tester);
    await submit(tester, '00012345');
    await tester.pumpAndSettle();

    expect(products.lookups, ['00012345']);
    expect(off.lookups, isEmpty);
    expect(opened.single.name, 'Biscoito');
    expect(find.text('Biscoito'), findsOneWidget);
    expect(refreshes, 0);
  });

  testWidgets('mostra loading, desabilita botão e importa do OFF', (
    tester,
  ) async {
    off.pending = Completer<Product?>();
    await pumpFeature(tester);
    await submit(tester, '7891000100103');

    expect(find.text('Consultando código…'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    off.pending!.complete(
      const Product(barcode: '7891000100103', name: 'Achocolatado'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Consultando código…'), findsNothing);
    expect(products.imported.single.barcode, '7891000100103');
    expect(opened.single.name, 'Achocolatado');
    expect(refreshes, 1);
  });

  testWidgets('ausente mostra estado vazio e permite consultar de novo', (
    tester,
  ) async {
    await pumpFeature(tester);
    await submit(tester, '00000000');
    await tester.pumpAndSettle();

    expect(find.text('Produto não encontrado'), findsOneWidget);
    expect(opened, isEmpty);

    off.response = const Product(barcode: '00000000', name: 'Agora existe');
    await tester.tap(find.text('Consultar novamente'));
    await tester.pumpAndSettle();

    expect(off.lookups, ['00000000', '00000000']);
    expect(opened.single.name, 'Agora existe');
  });

  testWidgets('erro exibe mensagem segura e retry refaz a consulta', (
    tester,
  ) async {
    off.error = const AppFailure(
      FailureKind.network,
      'Sem conexão. Verifique a internet.',
    );
    await pumpFeature(tester);
    await submit(tester, '7891000100103');
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão. Verifique a internet.'), findsOneWidget);
    expect(find.text('Produto não encontrado'), findsNothing);

    off
      ..error = null
      ..response = const Product(barcode: '7891000100103', name: 'Café');
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão. Verifique a internet.'), findsNothing);
    expect(opened.single.name, 'Café');
  });
}
