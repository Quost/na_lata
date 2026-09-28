import '../core/contracts.dart';
import '../core/models.dart';

const demoProducts = [
  Product(
    barcode: 'demo-leite-1',
    name: 'Leite integral',
    brand: 'Fazenda Aurora',
    category: 'Leite',
    isDemo: true,
  ),
  Product(
    barcode: 'demo-leite-2',
    name: 'Leite sem lactose',
    brand: 'Campo Bom',
    category: 'Leite',
    isDemo: true,
  ),
  Product(
    barcode: 'demo-chocolate-1',
    name: 'Chocolate ao leite',
    brand: 'Doce Serra',
    category: 'Chocolate',
    isDemo: true,
  ),
  Product(
    barcode: 'demo-chocolate-2',
    name: 'Chocolate 70%',
    brand: 'Fazenda Aurora',
    category: 'Chocolate',
    isDemo: true,
  ),
  Product(
    barcode: 'demo-batata-1',
    name: 'Batata palha tradicional',
    brand: 'Campo Bom',
    category: 'Batata palha',
    isDemo: true,
  ),
  Product(
    barcode: 'demo-batata-2',
    name: 'Batata palha extrafina',
    category: 'Batata palha',
    isDemo: true,
  ),
];

class DemoProducts implements ProductRepository {
  final _items = [...demoProducts];
  @override
  Future<List<Product>> search(ProductQuery query) async => _items
      .where(
        (p) =>
            p.name.toLowerCase().contains(query.text.toLowerCase()) &&
            (query.brand == null || query.brand == p.brand) &&
            (query.category == null || query.category == p.category),
      )
      .toList();
  @override
  Future<Product?> byBarcode(String barcode) async {
    for (final p in _items) {
      if (p.barcode == barcode) return p;
    }
    return null;
  }

  @override
  Future<void> importProduct(Product product) async {
    if (!_items.any((p) => p.barcode == product.barcode)) _items.add(product);
  }
}

class DemoReviews implements ReviewRepository {
  final _items = [
    Review(
      id: 'demo-review-1',
      barcode: 'demo-leite-1',
      userId: 'demo-peer',
      nickname: 'Colega fictício',
      rating: 4,
      comment: 'Bom para o café.',
      createdAt: DateTime.utc(2026, 9, 28),
    ),
    Review(
      id: 'demo-review-2',
      barcode: 'demo-chocolate-1',
      userId: 'demo-user',
      nickname: 'Você (demo)',
      rating: 2,
      comment: 'Achei muito doce.',
      createdAt: DateTime.utc(2026, 9, 28),
    ),
  ];
  @override
  Future<List<Review>> forProduct(String barcode) async =>
      _items.where((r) => r.barcode == barcode).toList();
  @override
  Future<List<Review>> mine() async =>
      _items.where((r) => r.userId == 'demo-user').toList();
  @override
  Future<void> save(ReviewDraft draft) async =>
      throw const FeaturePending('T08 — persistir avaliações');
  @override
  Future<void> delete(String reviewId) async =>
      throw const FeaturePending('T17 — excluir avaliação');
}

class DemoCommunity implements CommunityRepository {
  @override
  Future<Set<String>> favorites() async => {};
  @override
  Future<void> setFavorite(String barcode, bool value) async =>
      throw const FeaturePending('T18 — favoritos');
  @override
  Future<void> report(String reviewId, String reason) async =>
      throw const FeaturePending('T19 — denúncias');
  @override
  Future<List<Sighting>> sightings(String barcode) async => [];
  @override
  Future<void> addSighting(Sighting sighting) async =>
      throw const FeaturePending('T22 — onde encontrei');
  @override
  Future<void> setNickname(String nickname) async =>
      throw const FeaturePending('T23 — apelido');
}
