import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/data/auth_repository.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/features/auth/save_account_feature.dart';
import 'fake_auth.dart';

void main() {
  late FakeAuthRepository auth;

  Future<void> pump(WidgetTester tester) async {
    auth = FakeAuthRepository(current: userA);
    addTearDown(auth.close);
    final scope = AppScope(
      products: DemoProducts(),
      reviews: DemoReviews(),
      community: DemoCommunity(),
      openFoodFacts: HttpOpenFoodFactsRepository(),
      isDemo: false,
      userId: userA.userId,
      auth: auth,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SaveAccountFeature(
              context: FeatureContext(scope: scope, openProduct: (_) {}),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> sendEmail(WidgetTester tester, String email) async {
    await tester.tap(find.text('Salvar minha conta').last);
    await tester.pump();
    await tester.enterText(find.byType(TextField), email);
    await tester.tap(find.text('Enviar confirmação'));
    await tester.pumpAndSettle();
  }

  testWidgets('sucesso: confirmação pendente, mesmo userId e senha', (
    tester,
  ) async {
    await pump(tester);
    await sendEmail(tester, ' ana@exemplo.com ');
    expect(auth.linkedEmails, ['ana@exemplo.com']);
    expect(find.textContaining('Confirmação pendente'), findsOneWidget);
    expect(find.textContaining('ana@exemplo.com'), findsOneWidget);

    // Link do email aberto: mesma identidade, agora conta permanente.
    auth.confirmEmail();
    await tester.pumpAndSettle();
    expect(
      auth.current,
      const AuthIdentity(userId: 'user-a', isAnonymous: false),
    );
    expect(find.textContaining('Sua conta está salva'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'senhaforte1');
    await tester.enterText(find.byType(TextField).at(1), 'senhaforte1');
    await tester.tap(find.text('Salvar senha'));
    await tester.pumpAndSettle();
    expect(auth.passwordSets, 1);
    expect(find.textContaining('Senha salva'), findsOneWidget);
  });

  testWidgets(
    'email já usado: mensagem genérica, formulário e visitante mantidos',
    (tester) async {
      await pump(tester);
      auth.accountError = const AppFailure(
        FailureKind.conflict,
        emailUnavailableMessage,
      );
      await sendEmail(tester, 'outra@exemplo.com');
      expect(find.text(emailUnavailableMessage), findsOneWidget);
      expect(find.text('outra@exemplo.com'), findsOneWidget);
      expect(auth.current!.isAnonymous, isTrue);
      expect(auth.pendingEmail, isNull);
    },
  );

  testWidgets('email inválido não é enviado e cancelar mantém visitante', (
    tester,
  ) async {
    await pump(tester);
    await sendEmail(tester, 'sem-arroba');
    expect(find.text('Digite um email válido.'), findsOneWidget);
    expect(auth.linkedEmails, isEmpty);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(auth.current, userA);
  });

  testWidgets('pendente: ainda não confirmado e limite de reenvio', (
    tester,
  ) async {
    await pump(tester);
    await sendEmail(tester, 'ana@exemplo.com');

    await tester.tap(find.text('Já confirmei'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ainda não confirmado'), findsOneWidget);

    auth.accountError = const AppFailure(
      FailureKind.unavailable,
      'Muitas tentativas. Aguarde alguns minutos e tente de novo.',
    );
    await tester.tap(find.text('Reenviar email'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Muitas tentativas'), findsOneWidget);
    expect(auth.resendCalls, 0);
    expect(find.textContaining('Confirmação pendente'), findsOneWidget);
  });

  testWidgets('senhas diferentes não são enviadas', (tester) async {
    await pump(tester);
    auth.emit(
      const AuthSignedIn(AuthIdentity(userId: 'user-a', isAnonymous: false)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'senhaforte1');
    await tester.enterText(find.byType(TextField).at(1), 'outrasenha1');
    await tester.tap(find.text('Salvar senha'));
    await tester.pumpAndSettle();
    expect(find.text('As senhas não são iguais.'), findsOneWidget);
    expect(auth.passwordSets, 0);
  });
}
