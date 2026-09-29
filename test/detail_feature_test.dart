import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/detail/detail_feature.dart';

/// Helper para montar o widget de teste com Material e tema.
Widget _harness(FeatureContext ctx) => MaterialApp(
  theme: NaTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(child: DetailFeature(context: ctx)),
  ),
);

/// Cria um [AppScope] fake para testes.
AppScope _scope() => AppScope(
  products: DemoProducts(),
  reviews: DemoReviews(),
  community: DemoCommunity(),
  openFoodFacts: HttpOpenFoodFactsRepository(),
  isDemo: true,
  userId: 'demo-user',
);

void main() {
  group('T06 — DetailFeature', () {
    testWidgets('exibe nome, marca, categoria e barcode do produto completo', (
      tester,
    ) async {
      final scope = _scope();
      final product = const Product(
        barcode: '7891234567890',
        name: 'Suco de laranja',
        brand: 'Sucolândia',
        category: 'Sucos',
        imageUrl: 'https://example.com/suco.png',
      );
      final ctx = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (_) {},
      );
      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(find.text('Suco de laranja'), findsOneWidget);
      expect(find.text('Marca: Sucolândia'), findsOneWidget);
      expect(find.text('Categoria: Sucos'), findsOneWidget);
      expect(find.text('Código: 7891234567890'), findsOneWidget);

      scope.dispose();
    });

    testWidgets('exibe "Marca não informada" quando brand é null', (
      tester,
    ) async {
      final scope = _scope();
      final product = const Product(
        barcode: 'demo-sem-marca',
        name: 'Produto sem marca',
      );
      final ctx = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (_) {},
      );
      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(find.text('Marca: Marca não informada'), findsOneWidget);

      scope.dispose();
    });

    testWidgets('exibe "Sem categoria" quando category é null', (tester) async {
      final scope = _scope();
      final product = const Product(
        barcode: 'demo-sem-cat',
        name: 'Produto sem categoria',
        brand: 'Marca X',
      );
      final ctx = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (_) {},
      );
      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(find.text('Categoria: Sem categoria'), findsOneWidget);

      scope.dispose();
    });

    testWidgets('exibe placeholder quando imageUrl é null', (tester) async {
      final scope = _scope();
      final product = const Product(
        barcode: 'demo-sem-img',
        name: 'Produto sem imagem',
      );
      final ctx = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (_) {},
      );
      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(find.text('Imagem indisponível'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

      scope.dispose();
    });

    testWidgets('exibe badge DEMONSTRAÇÃO quando produto é demo', (
      tester,
    ) async {
      final scope = _scope();
      final product = const Product(
        barcode: 'demo-leite-1',
        name: 'Leite integral',
        brand: 'Fazenda Aurora',
        category: 'Leite',
        isDemo: true,
      );
      final ctx = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (_) {},
      );
      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(find.text('DEMONSTRAÇÃO'), findsOneWidget);
      expect(find.byIcon(Icons.science_outlined), findsOneWidget);

      scope.dispose();
    });

    testWidgets('não exibe badge DEMONSTRAÇÃO para produto real', (
      tester,
    ) async {
      final scope = _scope();
      final product = const Product(
        barcode: '7891234567890',
        name: 'Produto real',
        brand: 'Marca',
      );
      final ctx = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (_) {},
      );
      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(find.text('DEMONSTRAÇÃO'), findsNothing);

      scope.dispose();
    });

    testWidgets('exibe orientação quando product é null (Oficina)', (
      tester,
    ) async {
      final scope = _scope();
      final ctx = FeatureContext(
        scope: scope,
        product: null,
        openProduct: (_) {},
      );
      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum produto selecionado'), findsOneWidget);
      expect(
        find.text('Abra um produto pelo catálogo para ver a ficha.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      scope.dispose();
    });

    testWidgets('exibe placeholder de imagem se rede falhar', (tester) async {
      final scope = _scope();
      final product = const Product(
        barcode: 'demo-img-error',
        name: 'Erro de imagem',
        imageUrl: 'https://site-invalido.com/img.png', // Falha na rede do teste
      );
      final ctx = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (_) {},
      );
      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(find.text('Imagem indisponível'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

      scope.dispose();
    });

    testWidgets('ficha cabe em 320px com texto ampliado', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final scope = _scope();
      final product = const Product(
        barcode: '123',
        name: 'Nome muito grande',
        brand:
            'Marca super longa que poderia quebrar o layout se usasse Row comum',
        category: 'Categoria extensa',
      );
      final ctx = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (_) {},
      );

      await tester.pumpWidget(_harness(ctx));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // Garante que não houve overflow

      scope.dispose();
    });
  });
}
