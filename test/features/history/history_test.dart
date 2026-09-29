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

AppScope buildScope(ProductRepository products) => AppScope(
  products: products,
  reviews: DemoReviews(),
  community: DemoCommunity(),
  openFoodFacts: HttpOpenFoodFactsRepository(),
  isDemo: true,
  userId: 'demo-user',
);

void main() {
  group('addToHistory', () {
    test('coloca o mais recente primeiro', () {
      expect(addToHistory(['a', 'b'], 'c'), ['c', 'a', 'b']);
    });

    test('código repetido sobe para o topo sem duplicar', () {
      expect(addToHistory(['a', 'b', 'c'], 'b'), ['b', 'a', 'c']);
    });

    test('mantém no máximo 20 códigos, descartando o mais antigo', () {
      final full = [for (var i = 0; i < historyLimit; i++) 'code-$i'];
      final next = addToHistory(full, 'novo');
      expect(next, hasLength(historyLimit));
      expect(next.first, 'novo');
      expect(next, isNot(contains('code-${historyLimit - 1}')));
    });

    test('preserva zeros à esquerda e distingue códigos parecidos', () {
      expect(addToHistory(['789123'], '0789123'), ['0789123', '789123']);
    });

    test('ignora código vazio', () {
      expect(addToHistory(['a'], '  '), ['a']);
    });
  });

  group('HistoryStore', () {
    test('lê o que já estava salvo (sobrevive ao reinício)', () async {
      SharedPreferences.setMockInitialValues({
        historyKey: ['00123', '456'],
      });
      expect(await HistoryStore().load(), ['00123', '456']);
    });

    test('grava, reordena e persiste no SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final store = HistoryStore();
      await store.record('00111');
      await store.record('222');
      await store.record('00111');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(historyKey), ['00111', '222']);
      expect(await HistoryStore().load(), ['00111', '222']);
    });

    test('recordVisit grava o barcode do produto', () async {
      SharedPreferences.setMockInitialValues({});
      await recordVisit(const Product(barcode: '0001', name: 'Água'));
      expect(await HistoryStore().load(), ['0001']);
    });

    test('limpar remove todos os códigos', () async {
      SharedPreferences.setMockInitialValues({
        historyKey: ['1', '2'],
      });
      await HistoryStore().clear();
      expect(await HistoryStore().load(), isEmpty);
    });

    test('dado salvo em formato inválido gera erro, não lista vazia', () {
      SharedPreferences.setMockInitialValues({historyKey: 'quebrado'});
      expect(HistoryStore().load(), throwsA(isA<HistoryException>()));
    });

    test('recordVisit não propaga falha para a navegação', () async {
      SharedPreferences.setMockInitialValues({historyKey: 'quebrado'});
      await expectLater(
        recordVisit(const Product(barcode: '1', name: 'X')),
        completes,
      );
    });
  });

  group('HistoryFeature', () {
    late List<Product> opened;

    Future<AppScope> pump(
      WidgetTester tester, {
      ProductRepository? products,
    }) async {
      opened = [];
      final scope = buildScope(products ?? DemoProducts());
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: NaTheme.light,
          home: Scaffold(
            body: ListView(
              children: [
                HistoryFeature(
                  context: FeatureContext(
                    scope: scope,
                    openProduct: opened.add,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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
        historyKey: ['demo-chocolate-1', '0000123', 'demo-leite-1'],
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
        historyKey: ['demo-leite-2'],
      });
      await pump(tester);
      await tester.tap(find.text('Leite sem lactose'));
      expect(opened.single.barcode, 'demo-leite-2');
    });

    testWidgets('limpar pede confirmação e esvazia a lista', (tester) async {
      SharedPreferences.setMockInitialValues({
        historyKey: ['demo-leite-1'],
      });
      await pump(tester);

      await tester.tap(find.text('Limpar histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);

      await tester.tap(find.text('Limpar histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum produto visto ainda'), findsOneWidget);
      expect(await HistoryStore().load(), isEmpty);
    });

    testWidgets('nova visita registrada atualiza a lista aberta', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester);
      await recordVisit(demoProducts.first);
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);
    });

    testWidgets('mostra erro do catálogo e permite tentar novamente', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        historyKey: ['demo-leite-1'],
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
      SharedPreferences.setMockInitialValues({historyKey: 'quebrado'});
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
