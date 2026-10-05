import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/app.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';

void main() {
  testWidgets('template abre catálogo e navega até produto fictício', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scope = AppScope(
      products: DemoProducts(),
      reviews: DemoReviews(),
      community: DemoCommunity(),
      brandFollows: DemoBrandFollows(),
      openFoodFacts: HttpOpenFoodFactsRepository(),
      isDemo: true,
      isAuthenticated: true,
      userId: 'demo-user',
    );
    await tester.pumpWidget(NaLataApp(scope: scope));
    await tester.pumpAndSettle();
    expect(find.text('DEMONSTRAÇÃO'), findsOneWidget);
    await tester.tap(find.text('Leite integral'));
    await tester.pumpAndSettle();
    expect(
      find.text('Produto fictício • não importar para o Supabase'),
      findsOneWidget,
    );
    scope.dispose();
  });
}
