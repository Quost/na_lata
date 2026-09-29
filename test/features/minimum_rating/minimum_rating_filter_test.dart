import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/features/minimum_rating/minimum_rating_filter.dart';
import 'package:na_lata/features/summary/rating_summary.dart';
import 'fakes.dart';

RatedProduct _rated(String name, List<int> ratings) {
  final reviews = [
    for (final r in ratings)
      Review(
        id: '$name-$r',
        barcode: name,
        userId: 'u',
        nickname: 'n',
        rating: r,
        comment: '',
        createdAt: DateTime.utc(2026),
      ),
  ];
  return RatedProduct(
    product: Product(barcode: name, name: name),
    summary: summarizeReviews(reviews),
  );
}

List<String> _names(List<RatedProduct> items) =>
    items.map((i) => i.product.name).toList();

void main() {
  group('filterByMinimumRating', () {
    final items = [
      _rated('Sem nota', []),
      _rated('Três', [3]),
      _rated('Quatro exato', [4]),
      _rated('Quatro e meio', [5, 4]),
      _rated('Cinco', [5]),
    ];

    test('inclui média igual à nota mínima e exclui não avaliados', () {
      expect(_names(filterByMinimumRating(items, 4)), [
        'Cinco',
        'Quatro e meio',
        'Quatro exato',
      ]);
      expect(
        _names(filterByMinimumRating(items, 1)),
        isNot(contains('Sem nota')),
      );
      expect(filterByMinimumRating(items, 1), hasLength(4));
    });

    test('lista vazia quando nenhum produto alcança a nota', () {
      expect(
        filterByMinimumRating([
          _rated('Dois', [2]),
        ], 3),
        isEmpty,
      );
      expect(filterByMinimumRating([], 1), isEmpty);
    });

    test('desempata por quantidade e depois por nome', () {
      final tied = [
        _rated('beta', [4]),
        _rated('Alfa', [4]),
        _rated('Gama', [4, 4, 4]),
      ];
      expect(_names(filterByMinimumRating(tied, 4)), ['Gama', 'Alfa', 'beta']);
    });

    test('nota mínima fora de 1–5 é erro de programação', () {
      expect(() => filterByMinimumRating(items, 0), throwsRangeError);
      expect(() => filterByMinimumRating(items, 6), throwsRangeError);
    });
  });

  group('loadRatedProducts', () {
    test('respeita a consulta do catálogo e agrega todas as notas', () async {
      final loaded = await loadRatedProducts(
        const ProductQuery(brand: 'Fazenda Aurora'),
        products: DemoProducts(),
        reviews: FakeRatings(demoRatings()),
      );
      final byBarcode = {for (final i in loaded) i.product.barcode: i.summary};
      expect(
        byBarcode.keys,
        unorderedEquals(['demo-leite-1', 'demo-chocolate-2']),
      );
      expect(byBarcode['demo-leite-1']!.count, 2);
      expect(byBarcode['demo-leite-1']!.average, 4.5);
      expect(byBarcode['demo-chocolate-2']!.count, 3);
    });

    test('produto sem avaliação vem com média null', () async {
      final loaded = await loadRatedProducts(
        const ProductQuery(text: 'tradicional'),
        products: DemoProducts(),
        reviews: FakeRatings(demoRatings()),
      );
      expect(loaded.single.product.barcode, 'demo-batata-1');
      expect(loaded.single.summary.average, isNull);
    });
  });
}
