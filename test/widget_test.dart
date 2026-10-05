import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/app.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/features/history/history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppScope demoScope() => AppScope(
  products: DemoProducts(),
  reviews: DemoReviews(),
  community: DemoCommunity(),
  brandFollows: DemoBrandFollows(),
  openFoodFacts: HttpOpenFoodFactsRepository(),
  isDemo: true,
  isAuthenticated: true,
  userId: 'demo-user',
);

void main() {
  testWidgets('template abre catálogo e navega até produto fictício', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final scope = demoScope();
    await tester.pumpWidget(NaLataApp(scope: scope));
    await tester.pumpAndSettle();
    expect(find.text('DEMONSTRAÇÃO'), findsOneWidget);
    await tester.tap(find.text('Leite integral'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Produto de demonstração'), findsOneWidget);
    scope.dispose();
  });

  testWidgets('abrir produto registra a visita; renderizar não registra', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = HistoryStore(userId: 'demo-user');
    final scope = demoScope();
    addTearDown(scope.dispose);

    await tester.pumpWidget(NaLataApp(scope: scope));
    await tester.pumpAndSettle();
    expect(await store.load(), isEmpty);

    await tester.tap(find.text('Leite integral'));
    await tester.pumpAndSettle();
    expect([for (final v in await store.load()) v.barcode], ['demo-leite-1']);

    // Reconstruir a tela (mudança no escopo) não conta como nova visita.
    scope.refresh();
    await tester.pumpAndSettle();
    expect(await store.load(), hasLength(1));
  });
}
