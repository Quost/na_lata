import '../../core/contracts.dart';
import '../../core/models.dart';
import '../summary/rating_summary.dart';

/// Produto do catálogo com o resumo das avaliações do app.
class RatedProduct {
  const RatedProduct({required this.product, required this.summary});
  final Product product;
  final RatingSummary summary;
}

/// Busca o catálogo com a consulta atual e resume as notas de cada produto.
Future<List<RatedProduct>> loadRatedProducts(
  ProductQuery query, {
  required ProductRepository products,
  required ReviewRepository reviews,
}) async {
  final found = await products.search(query);
  return Future.wait(
    found.map(
      (product) async => RatedProduct(
        product: product,
        summary: summarizeReviews(await reviews.forProduct(product.barcode)),
      ),
    ),
  );
}

/// Mantém só avaliados com média >= [minimum] (1 a 5).
/// Ordena por média, depois quantidade e nome.
List<RatedProduct> filterByMinimumRating(
  List<RatedProduct> items,
  int minimum,
) {
  RangeError.checkValueInInterval(minimum, 1, 5, 'minimum');
  final result = items
      .where((item) => (item.summary.average ?? 0) >= minimum)
      .toList();
  result.sort((a, b) {
    final byAverage = b.summary.average!.compareTo(a.summary.average!);
    if (byAverage != 0) return byAverage;
    final byCount = b.summary.count.compareTo(a.summary.count);
    if (byCount != 0) return byCount;
    return a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
  });
  return result;
}
