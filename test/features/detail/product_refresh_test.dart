import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/features/detail/product_refresh.dart';

const barcode = '7891000100103';
const offImage =
    'https://images.openfoodfacts.org/images/products/789/front.jpg';

const current = Product(
  barcode: barcode,
  name: 'Leite condensado',
  brand: 'moça',
  category: 'en:condensed-milks',
);

TypeMatcher<AppFailure> failure(FailureKind kind) =>
    isA<AppFailure>().having((e) => e.kind, 'kind', kind);

void main() {
  group('catalogUpdateFrom', () {
    test('usa os campos da fonte quando informados', () {
      final update = catalogUpdateFrom(
        current,
        const Product(
          barcode: barcode,
          name: ' Leite condensado integral ',
          brand: 'Nestlé',
          category: 'en:sweetened-condensed-milks',
          imageUrl: offImage,
        ),
      );
      expect(update.barcode, barcode);
      expect(update.name, 'Leite condensado integral');
      expect(update.brand, 'nestlé');
      expect(update.category, 'en:sweetened-condensed-milks');
      expect(update.imageUrl, offImage);
    });

    test('campo ausente na fonte mantém o valor atual', () {
      final update = catalogUpdateFrom(
        current,
        const Product(barcode: barcode, name: offProductNameFallback),
      );
      expect(update.name, current.name);
      expect(update.brand, current.brand);
      expect(update.category, current.category);
      expect(catalogChanges(current, update), isEmpty);
    });

    test('foto fora do domínio da fonte é ignorada', () {
      for (final image in [
        'https://example.com/foto.jpg',
        'http://images.openfoodfacts.org/foto.jpg',
        'https://openfoodfacts.org.evil.example/foto.jpg',
      ]) {
        final update = catalogUpdateFrom(
          current,
          Product(barcode: barcode, name: current.name, imageUrl: image),
        );
        expect(update.imageUrl, isNull, reason: image);
      }
    });

    test('nunca troca o código de barras', () {
      final update = catalogUpdateFrom(
        current,
        const Product(barcode: '00000000000000', name: 'Outro'),
      );
      expect(update.barcode, barcode);
    });
  });

  group('catalogChanges', () {
    test('lista só os campos que mudam, com antes e depois', () {
      final changes = catalogChanges(
        current,
        const CatalogUpdate(
          barcode: barcode,
          name: 'Leite condensado integral',
          brand: 'moça',
          category: 'en:condensed-milks',
          imageUrl: offImage,
        ),
      );
      expect(changes.map((c) => c.label), ['Nome', 'Foto']);
      expect(changes.first.before, 'Leite condensado');
      expect(changes.first.after, 'Leite condensado integral');
      expect(changes.last.before, 'Sem foto');
    });

    test('espaço nas bordas e vazio não contam como mudança', () {
      final changes = catalogChanges(
        const Product(barcode: barcode, name: 'Leite', brand: ''),
        const CatalogUpdate(barcode: barcode, name: ' Leite ', brand: null),
      );
      expect(changes, isEmpty);
    });
  });

  group('validateCatalogUpdate', () {
    test('normaliza textos e marca', () {
      final valid = validateCatalogUpdate(
        const CatalogUpdate(
          barcode: ' $barcode ',
          name: ' Leite ',
          brand: ' Moça ',
          category: '  ',
        ),
      );
      expect(valid.barcode, barcode);
      expect(valid.name, 'Leite');
      expect(valid.brand, 'moça');
      expect(valid.category, isNull);
    });

    test('recusa código que não é de 8 a 14 dígitos', () {
      for (final code in ['demo-leite-1', '1234567', '123456789012345']) {
        expect(
          () => validateCatalogUpdate(CatalogUpdate(barcode: code, name: 'x')),
          throwsA(failure(FailureKind.validation)),
          reason: code,
        );
      }
    });

    test('recusa nome vazio ou com mais de 300 caracteres', () {
      for (final name in ['  ', 'a' * 301]) {
        expect(
          () => validateCatalogUpdate(
            CatalogUpdate(barcode: barcode, name: name),
          ),
          throwsA(failure(FailureKind.validation)),
        );
      }
      expect(
        validateCatalogUpdate(
          CatalogUpdate(barcode: barcode, name: 'é' * 300),
        ).name,
        hasLength(300),
      );
    });

    test('parâmetros da função têm só campos de catálogo', () {
      expect(
        catalogUpdateToParams(
          const CatalogUpdate(barcode: barcode, name: 'Leite'),
        ).keys,
        ['p_barcode', 'p_name', 'p_brand_key', 'p_category', 'p_image_url'],
      );
    });
  });

  group('DemoProductRefresh', () {
    late DemoProducts products;
    late DemoProductRefresh refresh;
    late DateTime now;

    setUp(() async {
      now = DateTime.utc(2026, 10, 5, 12);
      products = DemoProducts();
      await products.importProduct(current);
      refresh = DemoProductRefresh(products, clock: () => now);
    });

    test('grava campos de catálogo e registra a fonte', () async {
      final updated = await refresh.apply(
        const CatalogUpdate(
          barcode: barcode,
          name: 'Leite condensado integral',
          brand: 'moça',
          category: 'en:condensed-milks',
        ),
      );
      expect(updated.name, 'Leite condensado integral');
      expect(updated.sourceFetchedAt, now);
      expect(
        (await products.byBarcode(barcode))!.name,
        'Leite condensado integral',
      );
      // Continua sendo um único produto no catálogo.
      final found = await products.search(const ProductQuery(text: 'leite c'));
      expect(found.where((p) => p.barcode == barcode), hasLength(1));
    });

    test('sem diferença devolve a ficha sem gastar o limite', () async {
      const same = CatalogUpdate(
        barcode: barcode,
        name: 'Leite condensado',
        brand: 'moça',
        category: 'en:condensed-milks',
      );
      expect((await refresh.apply(same)).sourceFetchedAt, isNull);
      // Uma mudança real logo em seguida ainda é aceita.
      final updated = await refresh.apply(
        const CatalogUpdate(barcode: barcode, name: 'Novo nome'),
      );
      expect(updated.name, 'Novo nome');
    });

    test('segunda mudança dentro de uma hora é recusada', () async {
      await refresh.apply(const CatalogUpdate(barcode: barcode, name: 'Um'));
      now = now.add(const Duration(minutes: 59));
      await expectLater(
        refresh.apply(const CatalogUpdate(barcode: barcode, name: 'Dois')),
        throwsA(
          failure(
            FailureKind.unavailable,
          ).having((e) => e.message, 'message', contains('1 min')),
        ),
      );
      expect((await products.byBarcode(barcode))!.name, 'Um');

      now = now.add(const Duration(minutes: 1));
      final updated = await refresh.apply(
        const CatalogUpdate(barcode: barcode, name: 'Dois'),
      );
      expect(updated.name, 'Dois');
    });

    test('produto fora do catálogo é erro', () async {
      await expectLater(
        refresh.apply(
          const CatalogUpdate(barcode: '00000000000000', name: 'x'),
        ),
        throwsA(failure(FailureKind.unavailable)),
      );
    });
  });
}
