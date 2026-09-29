// Testes de T14 (ranking) — autoria da lógica: Leonardo Volpi.
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/features/ranking/ranking_feature.dart';

int _seq = 0;

Product _p(String barcode, String name, {String? category}) =>
    Product(barcode: barcode, name: name, category: category);

Review _r(String barcode, int rating) => Review(
  id: 'r${_seq++}',
  barcode: barcode,
  userId: 'u',
  nickname: 'n',
  rating: rating,
  comment: '',
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('buildRanking', () {
    test('ordena por média desc e exclui produtos sem avaliação', () {
      final products = [
        _p('a', 'Alfa', category: 'Doce'),
        _p('b', 'Bravo', category: 'Doce'),
        _p('c', 'Charlie', category: 'Salgado'),
        _p('d', 'Delta', category: 'Doce'), // sem avaliação -> fora
      ];
      final reviews = [
        _r('a', 5), _r('a', 3), // média 4,0 (2)
        _r('b', 5), // média 5,0 (1)
        _r('c', 2), // média 2,0 (1)
      ];
      final ranking = buildRanking(products: products, reviews: reviews);
      expect(ranking.map((e) => e.product.barcode).toList(), ['b', 'a', 'c']);
      expect(ranking.every((e) => e.count > 0), isTrue);
      expect(ranking.any((e) => e.product.barcode == 'd'), isFalse);
    });

    test('desempata por quantidade (desc) e depois por nome (asc)', () {
      final products = [_p('z', 'Zeta'), _p('a', 'Alfa'), _p('m', 'Meia')];
      // Todos com média 5,0. z e a com 2 avaliações; m com 1.
      final reviews = [
        _r('z', 5),
        _r('z', 5),
        _r('a', 5),
        _r('a', 5),
        _r('m', 5),
      ];
      final ranking = buildRanking(products: products, reviews: reviews);
      // Mais avaliações primeiro; empate de contagem resolve por nome asc.
      expect(ranking.map((e) => e.product.barcode).toList(), ['a', 'z', 'm']);
    });

    test('filtra por categoria', () {
      final products = [
        _p('a', 'Alfa', category: 'Doce'),
        _p('c', 'Charlie', category: 'Salgado'),
      ];
      final reviews = [_r('a', 4), _r('c', 5)];
      final doce = buildRanking(
        products: products,
        reviews: reviews,
        category: 'Doce',
      );
      expect(doce.map((e) => e.product.barcode).toList(), ['a']);
    });

    test('ignora notas fora do intervalo 1..5', () {
      final products = [_p('a', 'Alfa')];
      final reviews = [_r('a', 4), _r('a', 7)]; // 7 é descartada
      final ranking = buildRanking(products: products, reviews: reviews);
      expect(ranking.single.count, 1);
      expect(ranking.single.average, 4.0);
    });
  });

  group('evaluatedCategories', () {
    test('só categorias com produto avaliado, em ordem alfabética', () {
      final data = RankingData(
        products: [
          _p('a', 'Alfa', category: 'Doce'),
          _p('c', 'Charlie', category: 'Salgado'),
          _p('n', 'Nada', category: 'Bebida'), // sem avaliação
          _p('s', 'SemCategoria'), // categoria null
        ],
        reviews: [_r('a', 4), _r('c', 5), _r('s', 3)],
      );
      expect(evaluatedCategories(data), ['Doce', 'Salgado']);
    });
  });
}
