// Testes de T13 (marcas) — agregação por média ponderada.
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/features/brands/brands_feature.dart';

int _seq = 0;

Product _p(String barcode, String name, {String? brand}) =>
    Product(barcode: barcode, name: name, brand: brand);

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
  group('buildBrandStats', () {
    test('média ponderada agrega todas as reviews (não média das médias)', () {
      final products = [
        _p('a', 'Produto A', brand: 'Marca X'),
        _p('b', 'Produto B', brand: 'Marca X'),
      ];
      final reviewsByBarcode = {
        'a': [_r('a', 5), _r('a', 5)],
        'b': [_r('b', 1)],
      };
      final stats = buildBrandStats(
        products: products,
        reviewsByBarcode: reviewsByBarcode,
      );
      expect(stats, hasLength(1));
      final x = stats.single;
      expect(x.brand, 'Marca X');
      expect(x.totalReviews, 3);
      // Ponderada = (5+5+1)/3 = 11/3 ≈ 3,67 (não (5+1)/2 = 3,0).
      expect(x.average, closeTo(11 / 3, 1e-9));
      expect(x.products.map((p) => p.barcode).toList(), ['a', 'b']);
    });

    test('produtos sem marca ficam de fora (null ou vazio após trim)', () {
      final products = [
        _p('a', 'Com marca', brand: 'Marca X'),
        _p('b', 'Sem marca'), // brand null
        _p('c', 'Marca em branco', brand: '   '), // vira vazio no trim
      ];
      final stats = buildBrandStats(
        products: products,
        reviewsByBarcode: {
          'a': [_r('a', 4)],
        },
      );
      expect(stats.map((s) => s.brand).toList(), ['Marca X']);
    });

    test('ordena por média desc; marcas sem nota vão para o fim', () {
      final products = [
        _p('a', 'A', brand: 'Baixa'),
        _p('b', 'B', brand: 'Alta'),
        _p('c', 'C', brand: 'SemNota'),
      ];
      final stats = buildBrandStats(
        products: products,
        reviewsByBarcode: {
          'a': [_r('a', 2)],
          'b': [_r('b', 5)],
          // 'SemNota' sem avaliações
        },
      );
      expect(stats.map((s) => s.brand).toList(), ['Alta', 'Baixa', 'SemNota']);
      expect(stats.last.average, isNull);
      expect(stats.last.totalReviews, 0);
    });

    test('empate de média resolve por total (desc) e depois nome (asc)', () {
      final products = [
        _p('a', 'A', brand: 'Beta'),
        _p('b', 'B', brand: 'Alfa'),
      ];
      // Ambas média 5,0; Beta com 2 avaliações, Alfa com 1.
      final stats = buildBrandStats(
        products: products,
        reviewsByBarcode: {
          'a': [_r('a', 5), _r('a', 5)],
          'b': [_r('b', 5)],
        },
      );
      expect(stats.map((s) => s.brand).toList(), ['Beta', 'Alfa']);
    });
  });
}
