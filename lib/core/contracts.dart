import 'catalog_query.dart';
import 'models.dart';

abstract interface class ProductRepository {
  Future<List<Product>> search(ProductQuery query);
  Future<Product?> byBarcode(String barcode);
  Future<void> importProduct(Product product);
}

/// Catálogo paginado da nova jornada; convive com [ProductRepository.search]
/// até a migração dos consumidores.
abstract interface class CatalogRepository {
  Future<PageResult<Product>> page(
    CatalogQuery query, {
    CatalogCursor? after,
    int limit = 20,
  });
}

abstract interface class OpenFoodFactsRepository {
  Future<Product?> lookup(String barcode);
}

abstract interface class ReviewRepository {
  Future<List<Review>> forProduct(String barcode);
  Future<List<Review>> mine();
  Future<void> save(ReviewDraft draft);
  Future<void> delete(String reviewId);
}

abstract interface class CommunityRepository {
  Future<Set<String>> favorites();
  Future<void> setFavorite(String barcode, bool value);
  Future<void> report(String reviewId, String reason);
  Future<List<Sighting>> sightings(String barcode);
  Future<void> addSighting(Sighting sighting);
  Future<void> setNickname(String nickname);
}

abstract interface class BrandFollowRepository {
  Future<bool> isFollowing(String brandKey);
  Future<List<String>> followingBrands();
  Future<void> setFollowing({
    required String brandKey,
    required bool isFollowing,
  });
}

class FeaturePending implements Exception {
  const FeaturePending(this.task);
  final String task;
  @override
  String toString() => 'Entrega pendente: $task';
}
