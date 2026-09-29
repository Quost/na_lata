import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/features/edit_review/edit_review_logic.dart';

Review _review(
  String id,
  String barcode,
  DateTime createdAt, {
  int rating = 3,
  String comment = '',
}) => Review(
  id: id,
  barcode: barcode,
  userId: 'me',
  nickname: 'Eu',
  rating: rating,
  comment: comment,
  createdAt: createdAt,
);

void main() {
  group('findMyReview', () {
    final mine = [
      _review('a', '111', DateTime.utc(2026, 9, 1)),
      _review('b', '222', DateTime.utc(2026, 9, 2)),
    ];

    test('encontra a avaliação do produto', () {
      expect(findMyReview(mine, '222')?.id, 'b');
      expect(findMyReview(mine, ' 111 ')?.id, 'a');
    });

    test('retorna null quando não há avaliação do produto', () {
      expect(findMyReview(mine, '333'), isNull);
      expect(findMyReview([], '111'), isNull);
    });

    test('com duplicidade, usa a mais recente', () {
      final duplicated = [
        ...mine,
        _review('c', '111', DateTime.utc(2026, 9, 10)),
      ];
      expect(findMyReview(duplicated, '111')?.id, 'c');
    });
  });

  group('hasChanges', () {
    final original = _review(
      'a',
      '111',
      DateTime.utc(2026),
      rating: 4,
      comment: 'Bom',
    );

    test('sem mudança não há o que salvar', () {
      expect(hasChanges(original, rating: 4, comment: 'Bom'), isFalse);
      expect(hasChanges(original, rating: 4, comment: '  Bom  '), isFalse);
    });

    test('nota ou comentário diferente habilita salvar', () {
      expect(hasChanges(original, rating: 5, comment: 'Bom'), isTrue);
      expect(hasChanges(original, rating: 4, comment: 'Ótimo'), isTrue);
      expect(hasChanges(original, rating: 4, comment: ''), isTrue);
    });
  });

  test('formatReviewDate usa dia/mês/ano com dois dígitos', () {
    expect(formatReviewDate(DateTime(2026, 9, 5)), '05/09/2026');
    expect(formatReviewDate(DateTime(2026, 12, 31)), '31/12/2026');
  });
}
