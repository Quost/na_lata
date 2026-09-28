import '../core/contracts.dart';
import '../core/models.dart';

class HttpOpenFoodFactsRepository implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async {
    // T01: implementar HTTP, timeout, parsing e produto inexistente.
    throw const FeaturePending('T01 — Open Food Facts');
  }
}
