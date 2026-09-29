import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';

/// Notas por barcode; sem rede e sem depender do repositório real.
class FakeRatings implements ReviewRepository {
  FakeRatings(Map<String, List<int>> ratings)
    : ratings = {
        for (final e in ratings.entries) e.key: [...e.value],
      };
  final Map<String, List<int>> ratings;
  Object? failure;
  int calls = 0;

  @override
  Future<List<Review>> forProduct(String barcode) async {
    calls++;
    if (failure != null) throw failure!;
    var i = 0;
    return [
      for (final rating in ratings[barcode] ?? const <int>[])
        Review(
          id: '$barcode-${i++}',
          barcode: barcode,
          userId: 'user-$i',
          nickname: 'Colega $i',
          rating: rating,
          comment: '',
          createdAt: DateTime.utc(2026, 9, 28),
        ),
    ];
  }

  @override
  Future<List<Review>> mine() async => [];
  @override
  Future<void> save(ReviewDraft draft) async {}
  @override
  Future<void> delete(String reviewId) async {}
}

/// leite-1 4,5 (2) · leite-2 3,0 · chocolate-1 4,0 · chocolate-2 4,67 (3)
/// batata-1 sem avaliação · batata-2 2,0
Map<String, List<int>> demoRatings() => {
  'demo-leite-1': [5, 4],
  'demo-leite-2': [3],
  'demo-chocolate-1': [4],
  'demo-chocolate-2': [5, 5, 4],
  'demo-batata-2': [2],
};
