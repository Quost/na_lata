import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';

const leite = Product(
  barcode: 'demo-leite-1',
  name: 'Leite integral',
  brand: 'Fazenda Aurora',
);
const chocolate = Product(
  barcode: 'demo-chocolate-1',
  name: 'Chocolate ao leite',
  brand: 'Doce Serra',
);
const batata = Product(barcode: 'demo-batata-2', name: 'Batata palha');

Review review(String barcode, int rating, [String user = 'u']) => Review(
  id: '$barcode-$user-$rating',
  barcode: barcode,
  userId: user,
  nickname: user,
  rating: rating,
  comment: '',
  createdAt: DateTime.utc(2026, 9, 28),
);

/// Fixture de `summarizeReviews` enquanto a T10 não está no main.
RatingSummary fakeSummarize(List<Review> reviews) {
  final histogram = {for (var s = 1; s <= 5; s++) s: 0};
  var sum = 0;
  for (final r in reviews) {
    histogram[r.rating] = histogram[r.rating]! + 1;
    sum += r.rating;
  }
  return RatingSummary(
    average: reviews.isEmpty ? null : sum / reviews.length,
    count: reviews.length,
    histogram: histogram,
  );
}

class FakeCatalog implements ProductRepository {
  FakeCatalog([this.items = const []]);
  List<Product> items;
  Object? error;
  int searches = 0;

  @override
  Future<List<Product>> search(ProductQuery query) async {
    searches++;
    if (error != null) throw error!;
    return items;
  }

  @override
  Future<Product?> byBarcode(String barcode) async => null;
  @override
  Future<void> importProduct(Product product) async {}
}

class FakeReviews implements ReviewRepository {
  FakeReviews([List<Review> initial = const []]) : items = [...initial];
  final List<Review> items;
  final List<String> queried = [];
  Object? error;

  @override
  Future<List<Review>> forProduct(String barcode) async {
    queried.add(barcode);
    if (error != null) throw error!;
    return items.where((r) => r.barcode == barcode).toList();
  }

  @override
  Future<List<Review>> mine() async => [];
  @override
  Future<void> save(ReviewDraft draft) async {}
  @override
  Future<void> delete(String reviewId) async {}
}

/// A comparação não consulta o OFF; lança para detectar uso indevido.
class UnusedOpenFoodFacts implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) =>
      throw StateError('Comparação não deve consultar o OFF.');
}
