import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/features/compare/compare_logic.dart';

import 'fakes.dart';

void main() {
  group('CompareSelection', () {
    test('aceita dois produtos distintos, um em cada lado', () {
      final selection = const CompareSelection()
          .pick(0, leite.barcode)
          .pick(1, chocolate.barcode);

      expect(selection.isComplete, isTrue);
      expect(selection.barcodes, [leite.barcode, chocolate.barcode]);
    });

    test('impede o mesmo produto nos dois lados', () {
      final selection = const CompareSelection().pick(0, leite.barcode);

      expect(selection.duplicateError(1, leite.barcode), isNotNull);
      expect(() => selection.pick(1, leite.barcode), throwsArgumentError);
      // Trocar o produto do próprio lado não é duplicata.
      expect(selection.duplicateError(0, leite.barcode), isNull);
    });

    test('from mantém no máximo dois códigos distintos', () {
      final selection = CompareSelection.from([
        leite.barcode,
        leite.barcode,
        chocolate.barcode,
        batata.barcode,
      ]);

      expect(selection.barcodes, [leite.barcode, chocolate.barcode]);
    });

    test('recusa posição inexistente (máximo dois)', () {
      expect(
        () => const CompareSelection().pick(2, batata.barcode),
        throwsRangeError,
      );
    });
  });

  group('loadComparison', () {
    test('agrega avaliações de cada produto separadamente', () async {
      final reviews = FakeReviews([
        review(leite.barcode, 5, 'a'),
        review(leite.barcode, 3, 'b'),
        review(chocolate.barcode, 2, 'a'),
      ]);

      final result = await loadComparison(
        reviews: reviews,
        products: [leite, chocolate],
        summarize: fakeSummarize,
      );

      expect(reviews.queried, [leite.barcode, chocolate.barcode]);
      expect(result[0].summary.average, 4);
      expect(result[0].summary.count, 2);
      expect(result[0].summary.histogram[5], 1);
      expect(result[1].summary.average, 2);
      expect(result[1].summary.count, 1);
    });

    test('recusa mesmo produto duas vezes sem consultar repositório', () async {
      final reviews = FakeReviews();

      await expectLater(
        loadComparison(
          reviews: reviews,
          products: [leite, leite],
          summarize: fakeSummarize,
        ),
        throwsArgumentError,
      );
      expect(reviews.queried, isEmpty);
    });

    test('recusa quantidade diferente de dois', () async {
      await expectLater(
        loadComparison(
          reviews: FakeReviews(),
          products: [leite, chocolate, batata],
          summarize: fakeSummarize,
        ),
        throwsArgumentError,
      );
    });

    test('propaga falha do repositório em vez de devolver vazio', () async {
      final reviews = FakeReviews()
        ..error = const AppFailure(FailureKind.network, 'Sem conexão.');

      await expectLater(
        loadComparison(
          reviews: reviews,
          products: [leite, chocolate],
          summarize: fakeSummarize,
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('formatação e veredito', () {
    ComparedProduct entry(product, List<int> ratings) => ComparedProduct(
      product: product,
      summary: fakeSummarize([
        for (final r in ratings) review(product.barcode, r),
      ]),
    );

    test('formata média e quantidade', () {
      expect(formatAverage(null), 'Sem avaliações');
      expect(formatAverage(3.75), '3,8 de 5');
      expect(formatCount(0), 'Nenhuma avaliação');
      expect(formatCount(1), '1 avaliação');
      expect(formatCount(4), '4 avaliações');
    });

    test('aponta maior média, empate e ausência de notas', () {
      expect(
        compareVerdict(entry(leite, [5, 4]), entry(chocolate, [2])),
        'Leite integral tem a maior média.',
      );
      expect(
        compareVerdict(entry(leite, [4]), entry(chocolate, [4])),
        'Empate na média: 4,0 de 5.',
      );
      expect(
        compareVerdict(entry(leite, []), entry(chocolate, [3])),
        'Só Chocolate ao leite tem avaliações.',
      );
      expect(
        compareVerdict(entry(leite, []), entry(chocolate, [])),
        'Nenhum dos dois tem avaliações.',
      );
    });
  });
}
