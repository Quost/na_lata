import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/features/summary/rating_summary.dart';

Review review(int rating) => Review(
  id: 'r-$rating',
  barcode: '7891000100103',
  userId: 'u',
  nickname: 'n',
  rating: rating,
  comment: '',
  createdAt: DateTime.utc(2026, 9, 28),
);

void main() {
  group('summarizeReviews', () {
    test('lista vazia: média null, total 0 e cinco contagens zeradas', () {
      final summary = summarizeReviews(const []);
      expect(summary.average, isNull);
      expect(summary.count, 0);
      expect(summary.histogram, {1: 0, 2: 0, 3: 0, 4: 0, 5: 0});
    });

    test('notas [1,5,5]: média sem arredondar, total 3 e histograma', () {
      final summary = summarizeReviews([review(1), review(5), review(5)]);
      expect(summary.average, closeTo(11 / 3, 1e-9));
      expect(summary.average, isNot(3.7));
      expect(summary.count, 3);
      expect(summary.histogram, {1: 1, 2: 0, 3: 0, 4: 0, 5: 2});
    });

    test('uma única nota', () {
      final summary = summarizeReviews([review(4)]);
      expect(summary.average, 4);
      expect(summary.count, 1);
      expect(summary.histogram[4], 1);
    });

    test('a soma do histograma é igual ao total', () {
      final summary = summarizeReviews([
        review(1),
        review(2),
        review(2),
        review(3),
        review(5),
      ]);
      expect(summary.histogram.values.reduce((a, b) => a + b), summary.count);
    });

    test('nota fora de 1 a 5 é erro de programação, não é ignorada', () {
      expect(() => summarizeReviews([review(0)]), throwsRangeError);
      expect(() => summarizeReviews([review(6)]), throwsRangeError);
    });
  });
}