import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/features/scanner/scanner_feature.dart';
import 'package:na_lata/features/scanner/scanner_flow.dart';

class _FakeOff implements OpenFoodFactsRepository {
  _FakeOff([this.product]);
  final Product? product;
  final calls = <String>[];
  @override
  Future<Product?> lookup(String barcode) async {
    calls.add(barcode);
    return product;
  }
}

class _CountingProducts extends DemoProducts {
  int imports = 0;
  @override
  Future<void> importProduct(Product product) {
    imports++;
    return super.importProduct(product);
  }
}

const _real = Product(barcode: '0012345678905', name: 'Sardinha em lata');

void main() {
  test('normalizeBarcode aceita 8–14 dígitos e preserva zeros', () {
    expect(normalizeBarcode(' 0012345678905 '), '0012345678905');
    expect(normalizeBarcode('12345678'), '12345678');
    expect(normalizeBarcode('1234567'), isNull);
    expect(normalizeBarcode('123456789012345'), isNull);
    expect(normalizeBarcode('demo-leite-1'), isNull);
    expect(normalizeBarcode(null), isNull);
  });

  test('ScanGate entrega somente a primeira leitura válida', () {
    final gate = ScanGate();
    expect(gate.accept([null, 'abc']), isNull);
    expect(gate.done, isFalse);
    expect(gate.accept(['0012345678905', '78912345']), '0012345678905');
    expect(gate.accept(['78912345']), isNull);
    expect(gate.done, isTrue);
  });

  test('produto do catálogo não consulta OFF', () async {
    final products = _CountingProducts();
    await products.importProduct(_real);
    final off = _FakeOff();
    final found = await resolveBarcode(
      _real.barcode,
      products: products,
      openFoodFacts: off,
    );
    expect(found?.barcode, _real.barcode);
    expect(off.calls, isEmpty);
  });

  test('produto do OFF é importado uma única vez', () async {
    final products = _CountingProducts();
    final off = _FakeOff(_real);
    for (var i = 0; i < 2; i++) {
      final found = await resolveBarcode(
        _real.barcode,
        products: products,
        openFoodFacts: off,
      );
      expect(found?.name, 'Sardinha em lata');
    }
    expect(products.imports, 1);
    expect(off.calls, [_real.barcode]);
  });

  test('produto inexistente retorna null sem importar', () async {
    final products = _CountingProducts();
    final found = await resolveBarcode(
      '78900000',
      products: products,
      openFoodFacts: _FakeOff(),
    );
    expect(found, isNull);
    expect(products.imports, 0);
  });

  testWidgets('módulo não abre a câmera automaticamente', (tester) async {
    final scope = AppScope(
      products: DemoProducts(),
      reviews: DemoReviews(),
      community: DemoCommunity(),
      openFoodFacts: _FakeOff(),
      isDemo: true,
      userId: 'demo-user',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannerFeature(
            context: FeatureContext(scope: scope, openProduct: (_) {}),
          ),
        ),
      ),
    );
    expect(find.text('Escanear código'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    scope.dispose();
  });
}
