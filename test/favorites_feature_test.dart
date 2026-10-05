import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/features/favorites/favorites_feature.dart';

void main() {
  test('favorito demo é persistido e pode ser removido', () async {
    final community = DemoCommunity();

    await community.setFavorite('demo-leite-1', true);
    expect(await community.favorites(), {'demo-leite-1'});

    await community.setFavorite('demo-leite-1', false);
    expect(await community.favorites(), isEmpty);
  });

  testWidgets('ficha permite favoritar e desfavoritar o produto', (
    tester,
  ) async {
    final community = DemoCommunity();
    final scope = AppScope(
      products: DemoProducts(),
      reviews: DemoReviews(),
      community: community,
      openFoodFacts: _EmptyOpenFoodFacts(),
      isDemo: true,
      userId: 'demo-user',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavoritesFeature(
            context: FeatureContext(
              scope: scope,
              product: demoProducts.first,
              openProduct: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favoritar produto'));
    await tester.pumpAndSettle();
    expect(await community.favorites(), {'demo-leite-1'});
    expect(find.text('Remover dos favoritos'), findsOneWidget);

    await tester.tap(find.text('Remover dos favoritos'));
    await tester.pumpAndSettle();
    expect(await community.favorites(), isEmpty);
  });

  testWidgets('lista favoritos reabre a ficha do produto', (tester) async {
    final scope = AppScope(
      products: DemoProducts(),
      reviews: DemoReviews(),
      community: DemoCommunity(initialFavorites: {'demo-leite-1'}),
      openFoodFacts: _EmptyOpenFoodFacts(),
      isDemo: true,
      userId: 'demo-user',
    );
    Product? openedProduct;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavoritesFeature(
            context: FeatureContext(
              scope: scope,
              openProduct: (product) => openedProduct = product,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leite integral'), findsOneWidget);
    await tester.tap(find.text('Leite integral'));
    expect(openedProduct?.barcode, 'demo-leite-1');
  });
}

class _EmptyOpenFoodFacts implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}
