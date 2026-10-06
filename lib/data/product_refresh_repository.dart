import '../core/contracts.dart';
import '../core/models.dart';
import '../features/detail/product_refresh.dart';
import 'clients/app_failure.dart';
import 'clients/backend_client.dart';

/// CAT02 — grava na ficha os campos de catálogo vindos da fonte externa.
abstract interface class ProductRefreshRepository {
  /// Aplica [update] e devolve a ficha relida. Sem diferença, devolve a ficha
  /// como está. Falha se o produto foi atualizado há pouco ou não existe mais.
  /// Não repete a gravação.
  Future<Product> apply(CatalogUpdate update);
}

class SupabaseProductRefresh implements ProductRefreshRepository {
  SupabaseProductRefresh(this.client, this.products);
  final BackendClient client;
  final ProductRepository products;

  @override
  Future<Product> apply(CatalogUpdate update) async {
    final valid = validateCatalogUpdate(update);
    client.requireUserId;
    // products não tem UPDATE para o app: a função valida e limita a gravação.
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db.rpc('refresh_product', params: catalogUpdateToParams(valid))
            as List,
      ),
    );
    final row = rows.isEmpty ? const <String, dynamic>{} : rows.first;
    switch (row['status']) {
      case 'updated' || 'unchanged':
        final product = await products.byBarcode(valid.barcode);
        if (product == null) {
          throw const AppFailure(FailureKind.unavailable, productGoneMessage);
        }
        return product;
      case 'rate_limited':
        final seconds = row['retry_after_seconds'];
        throw refreshRateLimited(
          Duration(seconds: seconds is num ? seconds.toInt() : 0),
        );
      case 'not_found':
        throw const AppFailure(FailureKind.unavailable, productGoneMessage);
      default:
        throw const AppFailure(
          FailureKind.invalidResponse,
          'Resposta inesperada ao atualizar a ficha.',
        );
    }
  }
}
