import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/features/barcode/barcode_lookup.dart';

import 'fakes.dart';

void main() {
  group('validateBarcode', () {
    test('aceita 8 e 14 dígitos, inclusive com zeros à esquerda', () {
      expect(validateBarcode('00012345'), isNull);
      expect(validateBarcode('00000000000017'), isNull);
      expect(validateBarcode('  7891000100103 '), isNull);
    });

    test('rejeita vazio, curto, longo e não numérico', () {
      expect(validateBarcode(''), 'Digite o código de barras.');
      expect(validateBarcode(null), 'Digite o código de barras.');
      expect(validateBarcode('1234567'), contains('você digitou 7'));
      expect(validateBarcode('123456789012345'), contains('você digitou 15'));
      expect(validateBarcode('demo-leite-1'), 'Use apenas números.');
      expect(validateBarcode('7891 0001'), 'Use apenas números.');
    });

    test('normalizeBarcode preserva zeros e só remove espaços das bordas', () {
      expect(normalizeBarcode(' 00012345 '), '00012345');
    });
  });

  group('BarcodeLookup', () {
    const catalogProduct = Product(barcode: '00012345', name: 'No catálogo');
    const offProduct = Product(barcode: '7891000100103', name: 'Do OFF');

    test('encontra no catálogo sem consultar o OFF', () async {
      final products = FakeProducts([catalogProduct]);
      final off = FakeOpenFoodFacts();
      final result = await BarcodeLookup(
        products: products,
        openFoodFacts: off,
      ).find('00012345');

      expect(result, isA<BarcodeFound>());
      final found = result as BarcodeFound;
      expect(found.product.barcode, '00012345');
      expect(found.imported, isFalse);
      expect(products.lookups, ['00012345']);
      expect(off.lookups, isEmpty);
    });

    test('ausente no catálogo: consulta OFF e importa', () async {
      final products = FakeProducts();
      final off = FakeOpenFoodFacts()..response = offProduct;
      final result = await BarcodeLookup(
        products: products,
        openFoodFacts: off,
      ).find('7891000100103');

      expect((result as BarcodeFound).imported, isTrue);
      expect(result.product.name, 'Do OFF');
      expect(off.lookups, ['7891000100103']);
      expect(products.imported.single.barcode, '7891000100103');
    });

    test('ausente no catálogo e no OFF retorna não encontrado', () async {
      final products = FakeProducts();
      final result = await BarcodeLookup(
        products: products,
        openFoodFacts: FakeOpenFoodFacts(),
      ).find('00000000');

      expect(result, isA<BarcodeNotFound>());
      expect((result as BarcodeNotFound).barcode, '00000000');
      expect(products.imported, isEmpty);
    });

    test(
      'código demo ou inválido nunca chega ao catálogo nem ao OFF',
      () async {
        final products = FakeProducts();
        final off = FakeOpenFoodFacts();
        final lookup = BarcodeLookup(products: products, openFoodFacts: off);

        await expectLater(lookup.find('demo-leite-1'), throwsArgumentError);
        await expectLater(lookup.find('123'), throwsArgumentError);
        expect(products.lookups, isEmpty);
        expect(off.lookups, isEmpty);
      },
    );

    test('erro do OFF é propagado, não vira "não encontrado"', () async {
      final off = FakeOpenFoodFacts()
        ..error = const AppFailure(FailureKind.timeout, 'Tempo esgotado.');
      final lookup = BarcodeLookup(
        products: FakeProducts(),
        openFoodFacts: off,
      );

      await expectLater(
        lookup.find('7891000100103'),
        throwsA(isA<AppFailure>()),
      );
    });

    test('falha ao importar é propagada', () async {
      final products = FakeProducts()
        ..importError = const AppFailure(
          FailureKind.unauthorized,
          'Sem permissão.',
        );
      final off = FakeOpenFoodFacts()..response = offProduct;
      final lookup = BarcodeLookup(products: products, openFoodFacts: off);

      await expectLater(
        lookup.find('7891000100103'),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
