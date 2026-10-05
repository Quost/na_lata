import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/import/import_feature.dart';

class _NoOff implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}

/// Catálogo em memória que registra o que foi importado e pode falhar.
class _FakeProducts implements ProductRepository {
  final imported = <Product>[];
  Object? failure;

  @override
  Future<void> importProduct(Product product) async {
    if (failure != null) throw failure!;
    imported.add(product);
  }

  @override
  Future<List<Product>> search(ProductQuery query) async => imported;
  @override
  Future<Product?> byBarcode(String barcode) async => null;
}

class _Harness {
  _Harness({this.isDemo = true});
  final bool isDemo;
  final products = _FakeProducts();
  late final scope = AppScope(
    products: products,
    reviews: DemoReviews(),
    community: DemoCommunity(),
    openFoodFacts: _NoOff(),
    isDemo: isDemo,
    userId: 'demo-user',
  );
  int refreshes = 0;

  Future<void> pump(WidgetTester tester) async {
    scope.addListener(() => refreshes++);
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ImportFeature(
              context: FeatureContext(scope: scope, openProduct: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Finder _barcodeField() => find.byType(TextField).at(0);
Finder _nameField() => find.byType(TextField).at(1);
Finder _brandField() => find.byType(TextField).at(2);

Future<void> _tapImport(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Adicionar ao catálogo'));
  await tester.tap(find.text('Adicionar ao catálogo'));
}

void main() {
  group('validateImportForm', () {
    test('código de barras é obrigatório (trim)', () {
      expect(
        validateImportForm(barcode: '   ', name: 'Suco', isDemoMode: true),
        'Informe o código de barras do produto.',
      );
    });

    test('nome é obrigatório (trim)', () {
      expect(
        validateImportForm(barcode: 'demo-x', name: '   ', isDemoMode: true),
        'Informe o nome do produto.',
      );
    });

    test('no modo real recusa código iniciado por demo-', () {
      final error = validateImportForm(
        barcode: 'demo-x',
        name: 'Suco',
        isDemoMode: false,
      );
      expect(error, contains('reservados à demonstração'));
    });

    test('no modo demo aceita código demo-', () {
      expect(
        validateImportForm(barcode: 'demo-x', name: 'Suco', isDemoMode: true),
        isNull,
      );
    });

    test('código real válido passa nos dois modos', () {
      expect(
        validateImportForm(barcode: '789100', name: 'Suco', isDemoMode: false),
        isNull,
      );
      expect(
        validateImportForm(
          barcode: ' 789100 ',
          name: ' Suco ',
          isDemoMode: true,
        ),
        isNull,
      );
    });
  });

  group('ImportFeature', () {
    testWidgets('importa, limpa o formulário e chama refresh', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.enterText(_barcodeField(), 'demo-suco-1');
      await tester.enterText(_nameField(), '  Suco de uva  ');
      await tester.enterText(_brandField(), 'Fazenda Aurora');
      await _tapImport(tester);
      await tester.pumpAndSettle();
      final product = h.products.imported.single;
      expect(product.barcode, 'demo-suco-1');
      expect(product.name, 'Suco de uva');
      expect(product.brand, 'Fazenda Aurora');
      expect(product.category, isNull);
      expect(product.isDemo, isTrue);
      expect(h.refreshes, 1);
      expect(find.textContaining('Produto importado'), findsOneWidget);
      // Formulário limpo após o sucesso.
      expect(find.text('demo-suco-1'), findsNothing);
      h.scope.dispose();
    });

    testWidgets('sem nome não importa nem chama refresh', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.enterText(_barcodeField(), 'demo-suco-1');
      await _tapImport(tester);
      await tester.pump();
      expect(find.text('Informe o nome do produto.'), findsOneWidget);
      expect(h.products.imported, isEmpty);
      expect(h.refreshes, 0);
      h.scope.dispose();
    });

    testWidgets('modo real recusa código demo- sem chamar o repositório', (
      tester,
    ) async {
      final h = _Harness(isDemo: false);
      await h.pump(tester);
      await tester.enterText(_barcodeField(), 'demo-suco-1');
      await tester.enterText(_nameField(), 'Suco de uva');
      await _tapImport(tester);
      await tester.pump();
      expect(find.textContaining('reservados à demonstração'), findsOneWidget);
      expect(h.products.imported, isEmpty);
      expect(h.refreshes, 0);
      h.scope.dispose();
    });

    testWidgets('erro do repositório mostra mensagem segura e tenta de novo', (
      tester,
    ) async {
      final h = _Harness();
      h.products.failure = const AppFailure(
        FailureKind.unavailable,
        'Serviço indisponível. Tente novamente.',
      );
      await h.pump(tester);
      await tester.enterText(_barcodeField(), 'demo-suco-1');
      await tester.enterText(_nameField(), 'Suco de uva');
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Serviço indisponível. Tente novamente.'),
        findsOneWidget,
      );
      expect(h.refreshes, 0);
      // Campos preservados no erro permitem repetir sem redigitar.
      h.products.failure = null;
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(h.products.imported, hasLength(1));
      expect(h.refreshes, 1);
      h.scope.dispose();
    });
  });
}
