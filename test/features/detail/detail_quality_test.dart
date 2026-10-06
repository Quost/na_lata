import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/detail/detail_feature.dart';

const _source = 'https://world.openfoodfacts.org/product/7891000100103';
const _editUrl =
    'https://world.openfoodfacts.org/cgi/product.pl'
    '?type=edit&code=7891000100103';
const _action = 'Corrigir no Open Food Facts';

AppScope _scope() => AppScope(
  products: DemoProducts(),
  reviews: DemoReviews(),
  community: DemoCommunity(),
  openFoodFacts: HttpOpenFoodFactsRepository(),
  isDemo: true,
  userId: 'demo-user',
);

const _incomplete = Product(barcode: '7891000100103', name: 'Leite sem dados');

Product _complete() => Product(
  barcode: '7891000100103',
  name: 'Leite completo',
  brand: 'nestlé',
  imageUrl: 'https://example.com/leite.png',
  packageSize: PackageSize.tryCreate(
    1,
    PackageUnit.l,
    PackageSizeSource.offStructured,
  ),
);

Future<AppScope> _pump(
  WidgetTester tester,
  Product product, {
  String? sourceUrl,
  Future<bool> Function(Uri)? openLink,
}) async {
  final scope = _scope();
  final ctx = FeatureContext(
    scope: scope,
    product: product,
    openProduct: (_) {},
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: NaTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DetailFeature(
            context: ctx,
            sourceUrl: sourceUrl,
            openLink: openLink ?? (_) async => true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return scope;
}

Future<void> _tapAction(WidgetTester tester) async {
  final button = find.text(_action);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('CAT04 — qualidade da ficha', () {
    testWidgets('ficha completa mostra confirmação e nenhuma ação', (
      tester,
    ) async {
      final scope = await _pump(tester, _complete(), sourceUrl: _source);
      expect(
        find.text('Ficha completa: foto, marca e quantidade informadas.'),
        findsOneWidget,
      );
      expect(find.text(_action), findsNothing);
      expect(find.textContaining('Ficha incompleta'), findsNothing);
      scope.dispose();
    });

    testWidgets('ficha incompleta lista exatamente o que falta', (
      tester,
    ) async {
      final scope = await _pump(tester, _incomplete, sourceUrl: _source);
      expect(
        find.text('Ficha incompleta. Faltam: foto, marca, quantidade.'),
        findsOneWidget,
      );
      scope.dispose();
    });

    testWidgets('falta só a quantidade: indicação específica', (tester) async {
      final product = const Product(
        barcode: '7891000100103',
        name: 'Quase completo',
        brand: 'marca',
        imageUrl: 'https://example.com/a.png',
      );
      final scope = await _pump(tester, product, sourceUrl: _source);
      expect(
        find.text('Ficha incompleta. Faltam: quantidade.'),
        findsOneWidget,
      );
      scope.dispose();
    });

    testWidgets('link permitido abre exatamente a página de edição do OFF', (
      tester,
    ) async {
      final opened = <Uri>[];
      final scope = await _pump(
        tester,
        _incomplete,
        sourceUrl: _source,
        openLink: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await _tapAction(tester);
      expect(opened.map((u) => u.toString()), [_editUrl]);
      expect(find.textContaining('Não foi possível abrir'), findsNothing);
      scope.dispose();
    });

    testWidgets('falha ao abrir (false) é explicada e a ficha segue usável', (
      tester,
    ) async {
      var calls = 0;
      final scope = await _pump(
        tester,
        _incomplete,
        sourceUrl: _source,
        openLink: (_) async {
          calls++;
          return false;
        },
      );
      await _tapAction(tester);
      expect(
        find.textContaining('Não foi possível abrir o link'),
        findsOneWidget,
      );
      expect(find.text('Leite sem dados'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tapAction(tester); // pode tentar de novo
      expect(calls, 2);
      scope.dispose();
    });

    testWidgets('exceção ao abrir é tratada, sem vazar detalhes', (
      tester,
    ) async {
      final scope = await _pump(
        tester,
        _incomplete,
        sourceUrl: _source,
        openLink: (_) async => throw StateError('segredo-interno'),
      );
      await _tapAction(tester);
      expect(
        find.textContaining('Não foi possível abrir o link'),
        findsOneWidget,
      );
      expect(find.textContaining('segredo-interno'), findsNothing);
      expect(find.text('Leite sem dados'), findsOneWidget);
      expect(tester.takeException(), isNull);
      scope.dispose();
    });

    testWidgets('sem URL de fonte não há botão e a razão é explicada', (
      tester,
    ) async {
      final scope = await _pump(tester, _incomplete);
      expect(find.text(_action), findsNothing);
      expect(find.textContaining('Correção indisponível'), findsOneWidget);
      expect(
        find.text('Ficha incompleta. Faltam: foto, marca, quantidade.'),
        findsOneWidget,
      );
      scope.dispose();
    });

    testWidgets('URL de outro site também não gera ação', (tester) async {
      final scope = await _pump(
        tester,
        _incomplete,
        sourceUrl: 'https://example.com/produto/7891000100103',
      );
      expect(find.text(_action), findsNothing);
      expect(find.textContaining('Correção indisponível'), findsOneWidget);
      scope.dispose();
    });

    testWidgets('produto de demonstração não recebe seção de qualidade', (
      tester,
    ) async {
      final product = const Product(
        barcode: 'demo-leite-1',
        name: 'Leite integral',
        isDemo: true,
      );
      final scope = await _pump(tester, product, sourceUrl: _source);
      expect(find.textContaining('Ficha incompleta'), findsNothing);
      expect(find.textContaining('Ficha completa'), findsNothing);
      expect(find.text(_action), findsNothing);
      scope.dispose();
    });

    testWidgets('cabe em 320px com texto ampliado', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final scope = await _pump(
        tester,
        _incomplete,
        sourceUrl: _source,
        openLink: (_) async => false,
      );
      await _tapAction(tester);
      expect(tester.takeException(), isNull);
      scope.dispose();
    });
  });
}
