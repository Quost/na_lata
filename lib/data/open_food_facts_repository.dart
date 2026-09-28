import '../core/contracts.dart';
import 'clients/json_api_client.dart';
import '../core/models.dart';

class HttpOpenFoodFactsRepository implements OpenFoodFactsRepository {
  HttpOpenFoodFactsRepository({JsonApiClient? api})
    : api = api ?? JsonApiClient();
  final JsonApiClient api;
  @override
  Future<Product?> lookup(String barcode) async {
    // T01: implementar HTTP, timeout, parsing e produto inexistente.
    throw const FeaturePending('T01 — Open Food Facts');
  }
}
