import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/core/notification_contracts.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/notification_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/notifications/notification_preferences_controller.dart';
import 'package:na_lata/features/notifications/notification_preferences_feature.dart';

class _FakePrefs implements NotificationPreferencesRepository {
  _FakePrefs([this.stored = const NotificationPreferences()]);
  NotificationPreferences stored;
  Object? loadFailure;
  Object? saveFailure;

  bool persistThenFail = false;
  Completer<void>? loadGate;
  Completer<void>? saveGate;
  int loads = 0;
  int saves = 0;

  @override
  Future<NotificationPreferences> load() async {
    loads++;
    if (loadGate != null) await loadGate!.future;
    if (loadFailure != null) throw loadFailure!;
    return stored;
  }

  @override
  Future<NotificationPreferences> save(NotificationPreferences value) async {
    saves++;
    if (saveGate != null) await saveGate!.future;
    if (persistThenFail) stored = value;
    if (saveFailure != null) throw saveFailure!;
    stored = value;
    return stored;
  }
}

class _NoOff implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}

AppScope _scope(String userId, NotificationPreferencesRepository? repo) =>
    AppScope(
      products: DemoProducts(),
      reviews: DemoReviews(),
      community: DemoCommunity(),
      openFoodFacts: _NoOff(),
      isDemo: true,
      userId: userId,
      notificationPreferences: repo,
    );

Widget _host(AppScope scope) => MaterialApp(
  theme: NaTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(
      child: NotificationPreferencesFeature(
        context: FeatureContext(scope: scope, openProduct: (_) {}),
      ),
    ),
  ),
);

bool _switchOn(WidgetTester tester, String key) =>
    tester.widget<SwitchListTile>(find.byKey(Key(key))).value;

const _chosenOn = NotificationPreferences(
  replies: true,
  newFollowers: false,
  hasChosen: true,
);

void main() {
  group('controller', () {
    test('sem escolha anterior tudo começa desligado', () async {
      final controller = NotificationPreferencesController(_FakePrefs());
      await controller.load();
      expect(controller.status, NotificationPrefsStatus.ready);
      expect(controller.value.replies, isFalse);
      expect(controller.value.newFollowers, isFalse);
      expect(controller.value.hasChosen, isFalse);
    });

    test('alternar grava e passa a contar como escolha', () async {
      final repo = _FakePrefs();
      final controller = NotificationPreferencesController(repo);
      await controller.load();
      expect(await controller.setReplies(true), isTrue);
      expect(repo.stored.replies, isTrue);
      expect(repo.stored.newFollowers, isFalse);
      expect(controller.value.hasChosen, isTrue);
    });

    test('erro de escrita reverte o valor e informa o problema', () async {
      final repo = _FakePrefs()
        ..saveFailure = const AppFailure(FailureKind.unavailable, 'Falha X');
      final controller = NotificationPreferencesController(repo);
      await controller.load();
      expect(await controller.setReplies(true), isFalse);
      expect(controller.value.replies, isFalse);
      expect(controller.value.hasChosen, isFalse);
      expect(controller.saveError, 'Falha X');
      expect(repo.saves, 1);
    });

    test('exceção desconhecida não vaza detalhes para a UI', () async {
      final repo = _FakePrefs()..saveFailure = StateError('token=segredo');
      final controller = NotificationPreferencesController(repo);
      await controller.load();
      await controller.setNewFollowers(true);
      expect(controller.saveError, isNot(contains('segredo')));
      expect(controller.value.newFollowers, isFalse);
    });

    test('timeout reconcilia com o que o servidor gravou', () async {
      final repo = _FakePrefs()
        ..persistThenFail = true
        ..saveFailure = const AppFailure(FailureKind.timeout, 'Demorou');
      final controller = NotificationPreferencesController(repo);
      await controller.load();
      expect(await controller.setReplies(true), isFalse);
      expect(controller.value.replies, isTrue);
      expect(controller.saveError, 'Demorou');
    });

    test('ignora segundo toque enquanto grava', () async {
      final repo = _FakePrefs()..saveGate = Completer<void>();
      final controller = NotificationPreferencesController(repo);
      await controller.load();
      final first = controller.setReplies(true);
      expect(controller.saving, isTrue);
      expect(await controller.setNewFollowers(true), isFalse);
      repo.saveGate!.complete();
      expect(await first, isTrue);
      expect(repo.saves, 1);
      expect(repo.stored.newFollowers, isFalse);
    });

    test('falha ao carregar mostra erro e permite tentar de novo', () async {
      final repo = _FakePrefs()
        ..loadFailure = const AppFailure(FailureKind.network, 'Sem conexão.');
      final controller = NotificationPreferencesController(repo);
      await controller.load();
      expect(controller.status, NotificationPrefsStatus.failed);
      expect(controller.loadError, 'Sem conexão.');
      repo.loadFailure = null;
      await controller.load();
      expect(controller.status, NotificationPrefsStatus.ready);
    });
  });

  group('tela', () {
    testWidgets('carrega e mostra tudo desligado sem escolha', (tester) async {
      final repo = _FakePrefs()..loadGate = Completer<void>();
      await tester.pumpWidget(_host(_scope('user-a', repo)));
      expect(find.text('Carregando preferências…'), findsOneWidget);
      repo.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(_switchOn(tester, 'notif_replies'), isFalse);
      expect(_switchOn(tester, 'notif_followers'), isFalse);
      expect(find.byKey(const Key('notif_not_chosen')), findsOneWidget);
      expect(find.textContaining('Não enviamos e-mail'), findsOneWidget);
    });

    testWidgets('alternar liga a opção e grava', (tester) async {
      final repo = _FakePrefs();
      await tester.pumpWidget(_host(_scope('user-a', repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notif_replies')));
      await tester.pumpAndSettle();
      expect(_switchOn(tester, 'notif_replies'), isTrue);
      expect(repo.stored.replies, isTrue);
      expect(find.byKey(const Key('notif_not_chosen')), findsNothing);
    });

    testWidgets('erro de escrita reverte o toggle e mostra a mensagem', (
      tester,
    ) async {
      final repo = _FakePrefs()
        ..saveFailure = const AppFailure(FailureKind.unavailable, 'Falha X');
      await tester.pumpWidget(_host(_scope('user-a', repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notif_followers')));
      await tester.pumpAndSettle();
      expect(_switchOn(tester, 'notif_followers'), isFalse);
      expect(find.text('Falha X'), findsOneWidget);
    });

    testWidgets('erro ao carregar oferece tentar novamente', (tester) async {
      final repo = _FakePrefs(_chosenOn)
        ..loadFailure = const AppFailure(FailureKind.network, 'Sem conexão.');
      await tester.pumpWidget(_host(_scope('user-a', repo)));
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão.'), findsOneWidget);
      repo.loadFailure = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(_switchOn(tester, 'notif_replies'), isTrue);
    });

    testWidgets('trocar de conta recarrega as preferências corretas', (
      tester,
    ) async {
      final repoA = _FakePrefs(_chosenOn);
      final repoB = _FakePrefs();
      await tester.pumpWidget(_host(_scope('user-a', repoA)));
      await tester.pumpAndSettle();
      expect(_switchOn(tester, 'notif_replies'), isTrue);

      await tester.pumpWidget(_host(_scope('user-b', repoB)));
      await tester.pumpAndSettle();
      expect(_switchOn(tester, 'notif_replies'), isFalse);
      expect(find.byKey(const Key('notif_not_chosen')), findsOneWidget);
      expect(repoB.loads, 1);
    });

    testWidgets('resposta atrasada da conta anterior não aparece', (
      tester,
    ) async {
      final repoA = _FakePrefs(_chosenOn)..loadGate = Completer<void>();
      final repoB = _FakePrefs();
      await tester.pumpWidget(_host(_scope('user-a', repoA)));
      await tester.pumpWidget(_host(_scope('user-b', repoB)));
      await tester.pumpAndSettle();
      repoA.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(_switchOn(tester, 'notif_replies'), isFalse);
    });

    testWidgets('scope.refresh não recarrega nem perde o estado', (
      tester,
    ) async {
      final repo = _FakePrefs();
      final scope = _scope('user-a', repo);
      await tester.pumpWidget(_host(scope));
      await tester.pumpAndSettle();
      scope.refresh();
      await tester.pumpWidget(_host(scope));
      await tester.pumpAndSettle();
      expect(repo.loads, 1);
    });

    testWidgets('sem repositório mostra aviso de indisponível', (tester) async {
      await tester.pumpWidget(_host(_scope('user-a', null)));
      await tester.pumpAndSettle();
      expect(find.textContaining('não estão disponíveis'), findsOneWidget);
    });
  });

  test('demo guarda a escolha em memória', () async {
    final demo = DemoNotificationPreferences();
    expect((await demo.load()).hasChosen, isFalse);
    final saved = await demo.save(const NotificationPreferences(replies: true));
    expect(saved.hasChosen, isTrue);
    expect((await demo.load()).replies, isTrue);
  });
}
