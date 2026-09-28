import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/features/detail/detail_feature.dart';

/// Helper para montar o widget de teste com Material e tema.
Widget _harness(FeatureContext ctx) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: DetailFeature(context: ctx))),
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
      expect(find.text('Sucolândia'), findsOneWidget);
      expect(find.text('Sucos'), findsOneWidget);
      expect(find.text('7891234567890'), findsOneWidget);

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

      expect(find.text('Marca não informada'), findsOneWidget);

      scope.dispose();
    });

    testWidgets('exibe "Sem categoria" quando category é null', (
      tester,
    ) async {
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

      expect(find.text('Sem categoria'), findsOneWidget);

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
      expect(
        find.byIcon(Icons.image_not_supported_outlined),
        findsOneWidget,
      );

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

      expect(
        find.text(
          'Nenhum produto selecionado.\n'
          'Abra um produto pelo catálogo para ver a ficha.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      scope.dispose();
    });
  });
}
