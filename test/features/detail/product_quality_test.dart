import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/features/detail/product_quality.dart';

PackageSize? _size() => PackageSize.tryCreate(
  500,
  PackageUnit.g,
  PackageSizeSource.offStructured,
);

Product _product({String? imageUrl, String? brand, PackageSize? size}) =>
    Product(
      barcode: '7891000100103',
      name: 'Teste',
      brand: brand,
      imageUrl: imageUrl,
      packageSize: size,
    );

void main() {
  group('missingEssentialFields', () {
    test('ficha completa não tem campos ausentes', () {
      final product = _product(
        imageUrl: 'https://example.com/a.jpg',
        brand: 'nestlé',
        size: _size(),
      );
      expect(missingEssentialFields(product), isEmpty);
    });

    test('cada campo ausente é apontado individualmente', () {
      expect(
        missingEssentialFields(_product(brand: 'x', size: _size())),
        [MissingField.image],
      );
      expect(
        missingEssentialFields(_product(imageUrl: 'u', size: _size())),
        [MissingField.brand],
      );
      expect(
        missingEssentialFields(_product(imageUrl: 'u', brand: 'x')),
        [MissingField.quantity],
      );
    });

    test('tudo ausente, em ordem fixa foto, marca, quantidade', () {
      expect(missingEssentialFields(_product()), [
        MissingField.image,
        MissingField.brand,
        MissingField.quantity,
      ]);
    });

    test('texto vazio ou só espaços conta como ausente', () {
      final product = _product(imageUrl: '  ', brand: '', size: _size());
      expect(missingEssentialFields(product), [
        MissingField.image,
        MissingField.brand,
      ]);
    });
  });

  group('offEditUri', () {
    const code = '7891000100103';
    const edit =
        'https://world.openfoodfacts.org/cgi/product.pl?type=edit&code=$code';

    test('fonte do OFF gera a página de edição com host fixo', () {
      for (final source in [
        'https://world.openfoodfacts.org/product/$code',
        'https://br.openfoodfacts.org/produto/$code/leite',
        'https://openfoodfacts.org/product/$code',
        '  https://world.openfoodfacts.org/product/$code  ',
      ]) {
        expect(
          offEditUri(barcode: code, sourceUrl: source)?.toString(),
          edit,
          reason: source,
        );
      }
    });

    test('sem URL (manual ou antigo) não inventa link', () {
      expect(offEditUri(barcode: code, sourceUrl: null), isNull);
      expect(offEditUri(barcode: code, sourceUrl: ''), isNull);
      expect(offEditUri(barcode: code, sourceUrl: '   '), isNull);
    });

    test('rejeita HTTP, outro host, host parecido, credenciais e lixo', () {
      for (final source in [
        'http://world.openfoodfacts.org/product/$code',
        'https://example.com/product/$code',
        'https://openfoodfacts.org.evil.com/product/$code',
        'https://evilopenfoodfacts.org/product/$code',
        'https://user:pass@world.openfoodfacts.org/product/$code',
        'ftp://world.openfoodfacts.org/product/$code',
        'world.openfoodfacts.org/product/$code',
        'https://',
        ':::',
      ]) {
        expect(
          offEditUri(barcode: code, sourceUrl: source),
          isNull,
          reason: source,
        );
      }
    });

    test('código fora do padrão do OFF não gera link', () {
      for (final barcode in ['demo-leite-1', '123', '', 'abc12345678']) {
        expect(
          offEditUri(
            barcode: barcode,
            sourceUrl: 'https://world.openfoodfacts.org/product/1',
          ),
          isNull,
          reason: barcode,
        );
      }
    });
  });
}
