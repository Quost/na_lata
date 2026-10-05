import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/data/auth_repository.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/features/auth/session_controller.dart';
import 'package:na_lata/features/auth/session_gate.dart';
import 'fake_auth.dart';

void main() {
  late FakeAuthRepository auth;
  late SessionController session;
  late List<String> scopesCreated;

  Future<void> pumpGate(WidgetTester tester, {AuthIdentity? current}) async {
    auth = FakeAuthRepository(current: current);
    session = SessionController(auth);
    scopesCreated = [];
    addTearDown(() {
      session.dispose();
      return auth.close();
    });
    final products = DemoProducts();
    await tester.pumpWidget(
      SessionGate(
        controller: session,
        scopeFor: (userId) {
          scopesCreated.add(userId);
          return AppScope(
            products: products,
            reviews: DemoReviews(),
            community: DemoCommunity(),
            openFoodFacts: HttpOpenFoodFactsRepository(),
            isDemo: true,
            userId: userId,
          );
        },
      ),
    );
  }

  testWidgets('mostra carregando enquanto cria o visitante e depois o app', (
    tester,
  ) async {
    await pumpGate(tester);
    auth.holdSignIn = Completer();
    unawaited(session.start());
    await tester.pump();
    expect(find.text('Preparando sua sessão…'), findsOneWidget);

    auth.holdSignIn!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Catálogo'), findsWidgets);
    expect(scopesCreated, ['user-a']);
  });

  testWidgets(
    'erro no bootstrap mostra mensagem e recupera ao tentar de novo',
    (tester) async {
      await pumpGate(tester);
      auth.signInError = const AppFailure(
        FailureKind.network,
        'Sem conexão. Verifique sua internet.',
      );
      await session.start();
      await tester.pump();
      expect(find.text('Sessão não iniciada'), findsOneWidget);
      expect(find.text('Sem conexão. Verifique sua internet.'), findsOneWidget);

      auth.signInError = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo'), findsWidgets);
    },
  );

  testWidgets('sessão expirada mostra recuperação explícita', (tester) async {
    await pumpGate(tester, current: userA);
    await session.start();
    await tester.pumpAndSettle();
    auth.emit(const AuthSignedOut(expired: true));
    await tester.pumpAndSettle();
    expect(find.text('Sessão expirada'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets(
    'refresh de token mantém a tela aberta; troca A→B volta ao início',
    (tester) async {
      await pumpGate(tester, current: userA);
      await session.start();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leite integral'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Produto de demonstração'), findsOneWidget);

      auth.emit(const AuthSignedIn(userA)); // refresh
      await tester.pumpAndSettle();
      expect(find.textContaining('Produto de demonstração'), findsOneWidget);
      expect(scopesCreated, ['user-a']);

      auth.emit(const AuthSignedIn(userB));
      await tester.pumpAndSettle();
      expect(find.textContaining('Produto de demonstração'), findsNothing);
      expect(find.text('Leite integral'), findsOneWidget);
      expect(scopesCreated, ['user-a', 'user-b']);
    },
  );
}
