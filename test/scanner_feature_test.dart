import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/scanner/scanner_feature.dart';
import 'package:na_lata/features/scanner/scanner_page.dart';

const _sardinha = Product(barcode: '0012345678905', name: 'Sardinha em lata');

class _ScriptedOff implements OpenFoodFactsRepository {
  _ScriptedOff(this.answers);
  final List<Object?> answers;
  int calls = 0;
  @override
  Future<Product?> lookup(String barcode) async {
    final answer = answers[calls++ % answers.length];
    if (answer is Exception) throw answer;
    return answer as Product?;
  }
}

class _Harness {
  _Harness(OpenFoodFactsRepository off)
    : scope = AppScope(
        products: DemoProducts(),
        reviews: DemoReviews(),
        community: DemoCommunity(),
        openFoodFacts: off,
        isDemo: true,
        userId: 'demo-user',
      );
  final AppScope scope;
  final opened = <Product>[];

  Future<void> pump(WidgetTester tester, ScanResult? scan) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScannerFeature(
              context: FeatureContext(scope: scope, openProduct: opened.add),
              openScanner: (_) async => scan,
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('uma leitura importa e abre um único produto', (tester) async {
    final off = _ScriptedOff([_sardinha]);
    final h = _Harness(off);
    await h.pump(tester, const ScanResult.code('0012345678905'));
    expect(h.opened, isEmpty, reason: 'câmera não abre sozinha');
    await tester.tap(find.text('Escanear código'));
    await tester.pumpAndSettle();
    expect(h.opened.map((p) => p.barcode), ['0012345678905']);
    expect(await h.scope.products.byBarcode('0012345678905'), isNotNull);
    expect(off.calls, 1);
    h.scope.dispose();
  });

  testWidgets('câmera negada oferece digitação validada', (tester) async {
    final h = _Harness(_ScriptedOff([_sardinha]));
    await h.pump(tester, const ScanResult.manual());
    await tester.tap(find.text('Escanear código'));
    await tester.pumpAndSettle();
    expect(find.text('Digitar código'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Consultar'));
    await tester.pump();
    expect(find.text('Informe de 8 a 14 dígitos.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0012345678905');
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    expect(h.opened.single.name, 'Sardinha em lata');
    h.scope.dispose();
  });

  testWidgets('produto inexistente mostra estado vazio', (tester) async {
    final h = _Harness(_ScriptedOff([null]));
    await h.pump(tester, const ScanResult.code('78900000'));
    await tester.tap(find.text('Escanear código'));
    await tester.pumpAndSettle();
    expect(find.text('Produto não encontrado'), findsOneWidget);
    expect(h.opened, isEmpty);
    h.scope.dispose();
  });

  testWidgets('falha exibe mensagem segura e permite tentar novamente', (
    tester,
  ) async {
    final off = _ScriptedOff([
      const AppFailure(FailureKind.timeout, 'Tempo esgotado.'),
      _sardinha,
    ]);
    final h = _Harness(off);
    await h.pump(tester, const ScanResult.code('0012345678905'));
    await tester.tap(find.text('Escanear código'));
    await tester.pumpAndSettle();
    expect(find.text('Código 0012345678905: Tempo esgotado.'), findsOneWidget);
    expect(h.opened, isEmpty);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(h.opened.single.barcode, '0012345678905');
    expect(off.calls, 2);
    h.scope.dispose();
  });

  testWidgets('entrega pendente (T01) aparece como erro, não sucesso', (
    tester,
  ) async {
    final h = _Harness(_ScriptedOff([const FeaturePending('T01 — OFF')]));
    await h.pump(tester, const ScanResult.code('78900000'));
    await tester.tap(find.text('Escanear código'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Entrega pendente: T01'), findsOneWidget);
    expect(h.opened, isEmpty);
    h.scope.dispose();
  });
}
