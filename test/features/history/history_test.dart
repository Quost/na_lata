import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/history/history_feature.dart';
import 'package:na_lata/features/history/history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingProducts extends DemoProducts {
  var calls = 0;
  @override
  Future<Product?> byBarcode(String barcode) async {
    calls++;
    if (calls == 1) {
      throw const AppFailure(
        FailureKind.network,
        'Sem conexão. Verifique a internet e tente novamente.',
      );
    }
    return super.byBarcode(barcode);
  }
}

AppScope buildScope(ProductRepository products, {String userId = 'user-a'}) =>
    AppScope(
      products: products,
      reviews: DemoReviews(),
      community: DemoCommunity(),
      openFoodFacts: HttpOpenFoodFactsRepository(),
      isDemo: true,
      userId: userId,
    );

/// Conteúdo salvo no formato atual (v2) para montar cenários de teste.
String savedVisits(List<String> barcodes) => [
  '[',
  [
    for (final code in barcodes)
      '{"barcode":"$code","visitedAt":"2026-01-01T10:00:00.000"}',
  ].join(','),
  ']',
].join();

void main() {
  final t0 = DateTime(2026, 1, 1, 10);

  group('addToHistory', () {
    List<String> codes(List<HistoryVisit> visits) => [
      for (final visit in visits) visit.barcode,
    ];

    test('coloca o mais recente primeiro', () {
      final first = addToHistory([], 'a', t0);
      final second = addToHistory(first, 'b', t0);
      expect(codes(second), ['b', 'a']);
    });

    test('rever um código o move para o topo e atualiza o último acesso', () {
      final later = t0.add(const Duration(hours: 1));
      final current = [
        HistoryVisit('a', t0),
        HistoryVisit('b', t0),
        HistoryVisit('c', t0),
      ];
      final next = addToHistory(current, 'b', later);
      expect(codes(next), ['b', 'a', 'c']);
      expect(next.first.visitedAt, later);
    });

    test('mantém no máximo 50 códigos, descartando o mais antigo', () {
      expect(historyLimit, 50);
      var visits = <HistoryVisit>[];
      for (var i = 0; i < 51; i++) {
        visits = addToHistory(visits, 'code-$i', t0);
      }
      expect(visits, hasLength(50));
      expect(visits.first.barcode, 'code-50');
      expect(codes(visits), isNot(contains('code-0')));
    });

    test('preserva zeros à esquerda e distingue códigos parecidos', () {
      final next = addToHistory([HistoryVisit('789123', t0)], '0789123', t0);
      expect(codes(next), ['0789123', '789123']);
    });

    test('ignora código vazio', () {
      final current = [HistoryVisit('a', t0)];
      expect(addToHistory(current, '  ', t0), current);
    });
  });

  group('HistoryStore', () {
    Future<List<String>> codesOf(String userId) async => [
      for (final visit in await HistoryStore(userId: userId).load())
        visit.barcode,
    ];

    test('lê o que já estava salvo (sobrevive ao reinício)', () async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): savedVisits(['00123', '456']),
      });
      expect(await codesOf('user-a'), ['00123', '456']);
    });

    test('grava, reordena e persiste no SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final store = HistoryStore(userId: 'user-a');
      await store.record('00111');
      await store.record('222');
      await store.record('00111');
      expect(await codesOf('user-a'), ['00111', '222']);
    });

    test('guarda o último acesso de cada visita', () async {
      SharedPreferences.setMockInitialValues({});
      var now = t0;
      final store = HistoryStore(userId: 'user-a', now: () => now);
      await store.record('1');
      now = t0.add(const Duration(minutes: 5));
      await store.record('1');
      final visits = await store.load();
      expect(visits, hasLength(1));
      expect(visits.single.visitedAt, now);
    });

    test('contas diferentes não veem o histórico uma da outra', () async {
      SharedPreferences.setMockInitialValues({});
      await HistoryStore(userId: 'user-a').record('111');
      await HistoryStore(userId: 'user-b').record('222');
      expect(await codesOf('user-a'), ['111']);
      expect(await codesOf('user-b'), ['222']);
      expect(await codesOf('user-c'), isEmpty);
    });

    test('51 visitas mantêm só as 50 mais recentes', () async {
      SharedPreferences.setMockInitialValues({});
      final store = HistoryStore(userId: 'user-a');
      for (var i = 0; i < 51; i++) {
        await store.record('code-$i');
      }
      final codes = await codesOf('user-a');
      expect(codes, hasLength(50));
      expect(codes.first, 'code-50');
      expect(codes, isNot(contains('code-0')));
    });

    test('recordVisit grava o barcode do produto na conta informada', () async {
      SharedPreferences.setMockInitialValues({});
      await recordVisit(
        const Product(barcode: '0001', name: 'Água'),
        userId: 'user-a',
      );
      expect(await codesOf('user-a'), ['0001']);
      expect(await codesOf('user-b'), isEmpty);
    });

    test('limpar remove só os códigos da conta atual', () async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): savedVisits(['1', '2']),
        historyKeyFor('user-b'): savedVisits(['3']),
      });
      await HistoryStore(userId: 'user-a').clear();
      expect(await codesOf('user-a'), isEmpty);
      expect(await codesOf('user-b'), ['3']);
    });

    for (final (name, raw) in [
      ('texto que não é JSON', 'quebrado'),
      ('JSON que não é lista', '{"barcode":"1"}'),
      ('entrada sem data', '[{"barcode":"1"}]'),
      ('entrada com data inválida', '[{"barcode":"1","visitedAt":"ontem"}]'),
      (
        'entrada com código vazio',
        '[{"barcode":" ","visitedAt":"2026-01-01"}]',
      ),
    ]) {
      test('dado salvo inválido ($name) gera erro, não lista vazia', () {
        SharedPreferences.setMockInitialValues({historyKeyFor('user-a'): raw});
        expect(
          HistoryStore(userId: 'user-a').load(),
          throwsA(isA<HistoryException>()),
        );
      });
    }

    test('valor salvo com tipo errado gera erro', () {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): ['lista', 'antiga'],
      });
      expect(
        HistoryStore(userId: 'user-a').load(),
        throwsA(isA<HistoryException>()),
      );
    });

    test('recordVisit não propaga falha para a navegação', () async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): 'quebrado',
      });
      await expectLater(
        recordVisit(
          const Product(barcode: '1', name: 'X'),
          userId: 'user-a',
        ),
        completes,
      );
    });

    group('migração do histórico legado', () {
      test('vai para a primeira conta que abre e não é replicado', () async {
        SharedPreferences.setMockInitialValues({
          legacyHistoryKey: ['00123', '456'],
        });
        expect(await codesOf('user-a'), ['00123', '456']);
        expect(await codesOf('user-b'), isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(legacyHistoryKey), isFalse);
      });

      test('acontece uma única vez e não duplica ao reabrir', () async {
        SharedPreferences.setMockInitialValues({
          legacyHistoryKey: ['1', '2'],
        });
        await codesOf('user-a');
        await HistoryStore(userId: 'user-a').record('3');
        expect(await codesOf('user-a'), ['3', '1', '2']);
      });

      test('registrar uma visita também migra antes de gravar', () async {
        SharedPreferences.setMockInitialValues({
          legacyHistoryKey: ['1', '2'],
        });
        await HistoryStore(userId: 'user-a').record('9');
        expect(await codesOf('user-a'), ['9', '1', '2']);
        expect(await codesOf('user-b'), isEmpty);
      });

      test('não sobrescreve histórico que a conta já tem', () async {
        SharedPreferences.setMockInitialValues({
          legacyHistoryKey: ['velho'],
          historyKeyFor('user-a'): savedVisits(['atual']),
        });
        expect(await codesOf('user-a'), ['atual']);
        expect(await codesOf('user-b'), isEmpty);
      });

      test('respeita o limite e remove repetidos do legado', () async {
        SharedPreferences.setMockInitialValues({
          legacyHistoryKey: [
            for (var i = 0; i < 60; i++) 'code-$i',
            'code-0',
            '',
          ],
        });
        final codes = await codesOf('user-a');
        expect(codes, hasLength(50));
        expect(codes.first, 'code-0');
        expect(codes.toSet(), hasLength(50));
      });

      test(
        'formato legado ilegível é descartado sem derrubar a conta',
        () async {
          SharedPreferences.setMockInitialValues({
            legacyHistoryKey: 'quebrado',
          });
          expect(await codesOf('user-a'), isEmpty);
          expect(await codesOf('user-b'), isEmpty);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.containsKey(legacyHistoryKey), isFalse);
        },
      );
    });
  });

  group('HistoryFeature', () {
    late List<Product> opened;

    Widget host(AppScope scope) {
      return MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              HistoryFeature(
                context: FeatureContext(scope: scope, openProduct: opened.add),
              ),
            ],
          ),
        ),
      );
    }

    Future<AppScope> pump(
      WidgetTester tester, {
      ProductRepository? products,
      String userId = 'user-a',
    }) async {
      opened = [];
      final scope = buildScope(products ?? DemoProducts(), userId: userId);
      addTearDown(scope.dispose);
      await tester.pumpWidget(host(scope));
      await tester.pumpAndSettle();
      return scope;
    }

    testWidgets('mostra estado vazio sem histórico', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester);
      expect(find.text('Nenhum produto visto ainda'), findsOneWidget);
      expect(find.text('Limpar histórico'), findsNothing);
    });

    testWidgets('lista em ordem e trata código fora do catálogo', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): savedVisits([
          'demo-chocolate-1',
          '0000123',
          'demo-leite-1',
        ]),
      });
      await pump(tester);
      final chocolate = tester.getTopLeft(find.text('Chocolate ao leite'));
      final leite = tester.getTopLeft(find.text('Leite integral'));
      expect(chocolate.dy, lessThan(leite.dy));
      expect(find.text('Produto indisponível'), findsOneWidget);
      expect(
        find.text('Código 0000123 • não está mais no catálogo'),
        findsOneWidget,
      );

      await tester.tap(find.text('Produto indisponível'));
      await tester.pump();
      expect(
        find.text('O produto 0000123 não está mais no catálogo.'),
        findsOneWidget,
      );
      expect(opened, isEmpty);
    });

    testWidgets('tocar em um item reabre o produto', (tester) async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): savedVisits(['demo-leite-2']),
      });
      await pump(tester);
      await tester.tap(find.text('Leite sem lactose'));
      expect(opened.single.barcode, 'demo-leite-2');
    });

    testWidgets('outra conta não vê o histórico da primeira', (tester) async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): savedVisits(['demo-leite-1']),
      });
      await pump(tester, userId: 'user-b');
      expect(find.text('Nenhum produto visto ainda'), findsOneWidget);
      expect(find.text('Leite integral'), findsNothing);
    });

    testWidgets('trocar de conta com a tela aberta recarrega o histórico', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): savedVisits(['demo-leite-1']),
        historyKeyFor('user-b'): savedVisits(['demo-chocolate-1']),
      });
      opened = [];
      final scopeA = buildScope(DemoProducts(), userId: 'user-a');
      final scopeB = buildScope(DemoProducts(), userId: 'user-b');
      addTearDown(scopeA.dispose);
      addTearDown(scopeB.dispose);

      await tester.pumpWidget(host(scopeA));
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);

      await tester.pumpWidget(host(scopeB));
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsNothing);
      expect(find.text('Chocolate ao leite'), findsOneWidget);
    });

    testWidgets('limpar pede confirmação e esvazia só a conta atual', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): savedVisits(['demo-leite-1']),
        historyKeyFor('user-b'): savedVisits(['demo-chocolate-1']),
      });
      await pump(tester);

      await tester.tap(find.text('Limpar histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);
      expect((await HistoryStore(userId: 'user-a').load()), hasLength(1));

      await tester.tap(find.text('Limpar histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum produto visto ainda'), findsOneWidget);
      expect(await HistoryStore(userId: 'user-a').load(), isEmpty);
      expect(await HistoryStore(userId: 'user-b').load(), hasLength(1));
    });

    testWidgets('nova visita registrada atualiza a lista aberta', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester);
      await recordVisit(demoProducts.first, userId: 'user-a');
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);
    });

    testWidgets('mostra erro do catálogo e permite tentar novamente', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): savedVisits(['demo-leite-1']),
      });
      await pump(tester, products: FailingProducts());
      expect(find.text('Não foi possível carregar'), findsOneWidget);
      expect(
        find.text('Sem conexão. Verifique a internet e tente novamente.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);
    });

    testWidgets('histórico corrompido mostra erro e permite limpar', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        historyKeyFor('user-a'): 'quebrado',
      });
      await pump(tester);
      expect(find.textContaining('formato inválido'), findsOneWidget);

      await tester.tap(find.text('Limpar histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum produto visto ainda'), findsOneWidget);
    });
  });
}
