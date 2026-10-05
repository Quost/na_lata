import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/app.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/features/onboarding/onboarding_controller.dart';
import 'package:na_lata/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppScope _scope() => AppScope(
  products: DemoProducts(),
  reviews: DemoReviews(),
  community: DemoCommunity(),
  openFoodFacts: HttpOpenFoodFactsRepository(),
  isDemo: true,
  userId: 'demo-user',
);

Future<OnboardingController> _controller([
  Map<String, Object> stored = const {},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  final controller = OnboardingController();
  await controller.load();
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pumpApp(WidgetTester tester, OnboardingController c) async {
  final scope = _scope();
  addTearDown(scope.dispose);
  await tester.pumpWidget(NaLataApp(scope: scope, onboarding: c));
  await tester.pumpAndSettle();
}

/// A tela rola; em viewports pequenos o botão pode estar abaixo da dobra.
Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
}

Future<int?> _savedVersion() async =>
    (await SharedPreferences.getInstance()).getInt(onboardingVersionKey);

Future<String?> _savedRegion() async =>
    (await SharedPreferences.getInstance()).getString(onboardingRegionKey);

void main() {
  group('OnboardingController', () {
    test('primeiro uso deve aparecer; versão atual concluída não', () async {
      expect((await _controller()).shouldShow, isTrue);
      expect(
        (await _controller({
          onboardingVersionKey: onboardingVersion,
        })).shouldShow,
        isFalse,
      );
    });

    test('versão antiga concluída volta a apresentar o onboarding', () async {
      final c = await _controller({onboardingVersionKey: 0});
      expect(c.shouldShow, isTrue);
    });

    test('região salva desconhecida ou corrompida é ignorada', () async {
      final c = await _controller({
        onboardingVersionKey: onboardingVersion,
        onboardingRegionKey: 'cidade-inexistente',
      });
      expect(c.regionId, isNull);
    });

    test('concluir com região persiste versão e região', () async {
      final c = await _controller();
      await c.complete(regionId: 'joinville-sc');
      expect(c.shouldShow, isFalse);
      expect(await _savedVersion(), onboardingVersion);
      expect(await _savedRegion(), 'joinville-sc');
    });

    test('concluir sem região apaga a escolha anterior', () async {
      final c = await _controller({onboardingRegionKey: 'curitiba-pr'});
      await c.complete();
      expect(await _savedRegion(), isNull);
      expect(c.regionId, isNull);
    });

    test('falha ao ler o aparelho não bloqueia o app', () async {
      final c = OnboardingController(preferences: () => throw Exception('x'));
      await c.load();
      expect(c.shouldShow, isFalse);
    });

    test('falha ao gravar conclui só nesta sessão, sem erro', () async {
      final c = OnboardingController(preferences: () => throw Exception('x'));
      await c.complete(regionId: 'joinville-sc');
      expect(c.shouldShow, isFalse);
    });
  });

  group('fluxo no app', () {
    testWidgets('primeiro início mostra o onboarding e continuar abre a home', (
      tester,
    ) async {
      await _pumpApp(tester, await _controller());
      expect(find.text('Bem-vindo ao Na Lata'), findsOneWidget);
      expect(find.text('Leite integral'), findsNothing);

      await _tapText(tester, 'Joinville • SC');
      await tester.pump();
      await _tapText(tester, 'Continuar explorando');
      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo ao Na Lata'), findsNothing);
      expect(find.text('Leite integral'), findsOneWidget);
      expect(await _savedVersion(), onboardingVersion);
      expect(await _savedRegion(), 'joinville-sc');
    });

    testWidgets('pular conclui sem salvar região, GPS ou conta', (
      tester,
    ) async {
      await _pumpApp(tester, await _controller());
      await _tapText(tester, 'Curitiba • PR');
      await tester.pump();
      await _tapText(tester, 'Pular');
      await tester.pumpAndSettle();

      expect(find.text('Leite integral'), findsOneWidget);
      expect(await _savedVersion(), onboardingVersion);
      expect(await _savedRegion(), isNull);
    });

    testWidgets('já concluído não reaparece ao iniciar de novo', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        await _controller({onboardingVersionKey: onboardingVersion}),
      );
      expect(find.text('Bem-vindo ao Na Lata'), findsNothing);
      expect(find.text('Leite integral'), findsOneWidget);
    });

    testWidgets('ajuda reabre o onboarding e fechar volta à home', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        await _controller({
          onboardingVersionKey: onboardingVersion,
          onboardingRegionKey: 'curitiba-pr',
        }),
      );
      await tester.tap(find.byTooltip('Ajuda: rever a apresentação'));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo ao Na Lata'), findsOneWidget);
      // A escolha anterior vem marcada.
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Curitiba • PR'),
      );
      expect(chip.selected, isTrue);

      await _tapText(tester, 'Pular');
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo ao Na Lata'), findsNothing);
      expect(find.text('Leite integral'), findsOneWidget);
      expect(await _savedRegion(), isNull);
    });

    testWidgets('sem controller o app abre direto na home, sem ajuda', (
      tester,
    ) async {
      final scope = _scope();
      addTearDown(scope.dispose);
      await tester.pumpWidget(NaLataApp(scope: scope));
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);
      expect(find.byTooltip('Ajuda: rever a apresentação'), findsNothing);
    });
  });

  group('OnboardingPage', () {
    testWidgets('Salvar minha conta explica que ainda não existe', (
      tester,
    ) async {
      final c = await _controller();
      await tester.pumpWidget(MaterialApp(home: OnboardingPage(controller: c)));
      await tester.ensureVisible(find.text('Salvar minha conta'));
      await tester.tap(find.text('Salvar minha conta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ainda não está disponível'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ainda não está disponível'), findsNothing);
      expect(c.shouldShow, isTrue, reason: 'não cria cadastro nem conclui');
    });

    testWidgets('onSaveAccount injetado substitui o aviso', (tester) async {
      final c = await _controller();
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingPage(
            controller: c,
            onSaveAccount: () => called = true,
          ),
        ),
      );
      await tester.ensureVisible(find.text('Salvar minha conta'));
      await tester.tap(find.text('Salvar minha conta'));
      await tester.pump();
      expect(called, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('cabe em 320px com texto a 200% e botões acessíveis', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await _controller();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: OnboardingPage(controller: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Continuar explorando'));
      await tester.ensureVisible(find.text('Pular'));
      await tester.ensureVisible(find.text('Salvar minha conta'));
      expect(tester.takeException(), isNull);
    });
  });
}
