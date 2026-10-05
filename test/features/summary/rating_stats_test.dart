import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/features/summary/rating_stats.dart';
import 'package:na_lata/features/summary/rating_summary.dart';

/// Helper para criar reviews com valores previsíveis.
Review _review({
  required String barcode,
  required int rating,
  String id = 'r',
  String userId = 'u',
}) => Review(
  id: id,
  barcode: barcode,
  userId: userId,
  nickname: 'n',
  rating: rating,
  comment: '',
  createdAt: DateTime.utc(2026, 10, 5),
);

void main() {
  group('computeStats — produto individual', () {
    test('sem avaliações: média null, count 0, histograma zerado', () {
      final stats = computeStats('abc', []);

      expect(stats.barcode, 'abc');
      expect(stats.average, isNull);
      expect(stats.count, 0);
      expect(stats.histogram, {1: 0, 2: 0, 3: 0, 4: 0, 5: 0});
    });

    test('uma avaliação: média igual à nota, count 1', () {
      final stats = computeStats('abc', [_review(barcode: 'abc', rating: 4)]);

      expect(stats.average, 4.0);
      expect(stats.count, 1);
      expect(stats.histogram[4], 1);
      expect(stats.histogram[1], 0);
    });

    test('distribuição conhecida [1,5,5]: média 3.666..., count 3', () {
      final reviews = [
        _review(barcode: 'x', rating: 1, id: 'r1'),
        _review(barcode: 'x', rating: 5, id: 'r2'),
        _review(barcode: 'x', rating: 5, id: 'r3'),
      ];
      final stats = computeStats('x', reviews);

      expect(stats.average, closeTo(11 / 3, 0.0001));
      expect(stats.count, 3);
      expect(stats.histogram, {1: 1, 2: 0, 3: 0, 4: 0, 5: 2});
    });

    test('não arredonda a média antes de retornar (precisão para ranking)', () {
      final reviews = [
        _review(barcode: 'a', rating: 1, id: 'r1'),
        _review(barcode: 'a', rating: 2, id: 'r2'),
        _review(barcode: 'a', rating: 3, id: 'r3'),
      ];
      final stats = computeStats('a', reviews);

      // Média é 2.0 exata, mas testamos que não arredonda para int.
      expect(stats.average, isA<double>());
      expect(stats.average, 2.0);
    });

    test('rating fora de 1-5 lança RangeError', () {
      expect(
        () => computeStats('abc', [_review(barcode: 'abc', rating: 0)]),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => computeStats('abc', [_review(barcode: 'abc', rating: 6)]),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('computeStatsBatch — lote sem N+1', () {
    test('agrupa reviews por barcode em uma passagem', () {
      final reviews = [
        _review(barcode: 'p1', rating: 5, id: 'r1'),
        _review(barcode: 'p2', rating: 3, id: 'r2'),
        _review(barcode: 'p1', rating: 1, id: 'r3'),
        _review(barcode: 'p2', rating: 4, id: 'r4'),
        _review(barcode: 'p3', rating: 2, id: 'r5'),
      ];

      final batch = computeStatsBatch(reviews);

      expect(batch.length, 3);
      // p1: [5, 1] -> média 3.0, count 2
      expect(batch['p1']!.average, 3.0);
      expect(batch['p1']!.count, 2);
      // p2: [3, 4] -> média 3.5, count 2
      expect(batch['p2']!.average, 3.5);
      expect(batch['p2']!.count, 2);
      // p3: [2] -> média 2.0, count 1
      expect(batch['p3']!.average, 2.0);
      expect(batch['p3']!.count, 1);
    });

    test('barcodes sem avaliação retornam stats vazios (não são omitidos)', () {
      final reviews = [_review(barcode: 'p1', rating: 5, id: 'r1')];

      final batch = computeStatsBatch(reviews, barcodes: ['p1', 'p2', 'p3']);

      expect(batch.length, 3);
      expect(batch['p1']!.count, 1);
      expect(batch['p2']!.average, isNull);
      expect(batch['p2']!.count, 0);
      expect(batch['p3']!.average, isNull);
      expect(batch['p3']!.count, 0);
    });

    test('lista vazia de reviews com barcodes retorna tudo zerado', () {
      final batch = computeStatsBatch([], barcodes: ['a', 'b']);

      expect(batch.length, 2);
      expect(batch['a']!.count, 0);
      expect(batch['b']!.count, 0);
    });

    test('lista vazia sem barcodes retorna mapa vazio', () {
      final batch = computeStatsBatch([]);
      expect(batch, isEmpty);
    });

    test('cada review conta uma vez (sem duplicação)', () {
      final review = _review(barcode: 'p1', rating: 4, id: 'r1');

      // Mesma review, mas na lista duas vezes (simula bug de duplicação).
      final batch = computeStatsBatch([review, review]);

      // Conta 2 vezes porque são 2 entradas na lista — o contrato é que a
      // lista de entrada já está correta. A função apenas agrega.
      expect(batch['p1']!.count, 2);
    });
  });

  group('computeStats concorda com summarizeReviews', () {
    test('resultado idêntico para mesmo conjunto de reviews', () {
      final reviews = [
        _review(barcode: 'x', rating: 1, id: 'r1'),
        _review(barcode: 'x', rating: 3, id: 'r2'),
        _review(barcode: 'x', rating: 5, id: 'r3'),
        _review(barcode: 'x', rating: 5, id: 'r4'),
      ];

      final stats = computeStats('x', reviews);
      final summary = summarizeReviews(reviews);

      expect(stats.average, summary.average);
      expect(stats.count, summary.count);
      expect(stats.histogram, summary.histogram);
    });

    test('sem reviews ambos retornam null/0', () {
      final stats = computeStats('x', []);
      final summary = summarizeReviews([]);

      expect(stats.average, summary.average);
      expect(stats.count, summary.count);
      expect(stats.histogram, summary.histogram);
    });
  });

  group('simulação de edição e exclusão', () {
    test('editar nota recalcula média corretamente', () {
      var reviews = [
        _review(barcode: 'p', rating: 5, id: 'r1', userId: 'u1'),
        _review(barcode: 'p', rating: 3, id: 'r2', userId: 'u2'),
      ];

      var stats = computeStats('p', reviews);
      expect(stats.average, 4.0);
      expect(stats.count, 2);

      // Simular edição: u2 muda de 3 para 1.
      reviews = [
        _review(barcode: 'p', rating: 5, id: 'r1', userId: 'u1'),
        _review(barcode: 'p', rating: 1, id: 'r2', userId: 'u2'),
      ];

      stats = computeStats('p', reviews);
      expect(stats.average, 3.0);
      expect(stats.count, 2);
      expect(stats.histogram[3], 0); // Nota anterior sumiu.
      expect(stats.histogram[1], 1); // Nova nota aparece.
    });

    test('excluir review reduz count e recalcula', () {
      var reviews = [
        _review(barcode: 'p', rating: 5, id: 'r1'),
        _review(barcode: 'p', rating: 3, id: 'r2'),
        _review(barcode: 'p', rating: 1, id: 'r3'),
      ];

      var stats = computeStats('p', reviews);
      expect(stats.average, 3.0);
      expect(stats.count, 3);

      // Simular exclusão do r2 (nota 3).
      reviews = [
        _review(barcode: 'p', rating: 5, id: 'r1'),
        _review(barcode: 'p', rating: 1, id: 'r3'),
      ];

      stats = computeStats('p', reviews);
      expect(stats.average, 3.0); // (5+1)/2 = 3.0
      expect(stats.count, 2);
      expect(stats.histogram[3], 0);
    });
  });
}
