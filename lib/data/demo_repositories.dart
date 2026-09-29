import '../core/contracts.dart';
import '../core/models.dart';
import '../features/report/report_logic.dart';
import '../features/sightings/sighting_logic.dart';
import 'clients/app_failure.dart';
import 'supabase_reviews.dart' show validateReviewDraft;

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
  /// Usuário da sessão fictícia; o formulário nunca informa o autor.
  static const userId = 'demo-user';
  static const nickname = 'Você (demo)';
  var _nextId = 3;
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
      userId: userId,
      nickname: nickname,
      rating: 2,
      comment: 'Achei muito doce.',
      createdAt: DateTime.utc(2026, 9, 28),
    ),
  ];
  List<Review> _newestFirst(Iterable<Review> reviews) =>
      reviews.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Future<List<Review>> forProduct(String barcode) async =>
      _newestFirst(_items.where((r) => r.barcode == barcode.trim()));
  @override
  Future<List<Review>> mine() async =>
      _newestFirst(_items.where((r) => r.userId == userId));

  /// Mesmo contrato do banco: upsert por (barcode, user_id), mantendo id e data.
  @override
  Future<void> save(ReviewDraft draft) async {
    final valid = validateReviewDraft(draft);
    final index = _items.indexWhere(
      (r) => r.barcode == valid.barcode && r.userId == userId,
    );
    final previous = index >= 0 ? _items[index] : null;
    final review = Review(
      id: previous?.id ?? 'demo-review-${_nextId++}',
      barcode: valid.barcode,
      userId: userId,
      nickname: nickname,
      rating: valid.rating,
      comment: valid.comment,
      createdAt: previous?.createdAt ?? DateTime.now().toUtc(),
    );
    if (index >= 0) {
      _items[index] = review;
    } else {
      _items.add(review);
    }
  }

  /// T17 — exclusão: remove só a avaliação própria; 0 linhas não é sucesso.
  @override
  Future<void> delete(String reviewId) async {
    final index = _items.indexWhere(
      (r) => r.id == reviewId && r.userId == userId,
    );
    if (index < 0) {
      throw const AppFailure(
        FailureKind.unavailable,
        'Avaliação não encontrada.',
      );
    }
    _items.removeAt(index);
  }
}

class DemoCommunity implements CommunityRepository {
  DemoCommunity({Set<String> initialFavorites = const {}})
    : _favorites = {...initialFavorites};

  final Set<String> _favorites;

  /// T19 — modo demo tem um único usuário; uma denúncia por comentário.
  final Set<String> _reportedReviews = {};

  /// T22 — relatos em memória, por código de barras.
  final List<Sighting> _sightings = [];

  /// T23 — apelido escolhido nesta sessão demo (só para feedback local).
  String? _nickname;
  String? get nickname => _nickname;

  @override
  Future<Set<String>> favorites() async => {..._favorites};
  @override
  Future<void> setFavorite(String barcode, bool value) async {
    if (value) {
      _favorites.add(barcode);
    } else {
      _favorites.remove(barcode);
    }
  }

  @override
  Future<void> report(String reviewId, String reason) async {
    if (ReportReason.tryParse(reason) == null || reviewId.trim().isEmpty) {
      throw const AppFailure(
        FailureKind.validation,
        'Escolha um motivo: ofensa, spam ou outro.',
      );
    }
    // add() devolve false quando o comentário já foi denunciado.
    if (!_reportedReviews.add(reviewId)) {
      throw const AppFailure(FailureKind.conflict, duplicateReportMessage);
    }
  }

  @override
  Future<List<Sighting>> sightings(String barcode) async =>
      _sightings.where((s) => s.barcode == barcode.trim()).toList();

  @override
  Future<void> addSighting(Sighting sighting) async {
    final valid = validateSighting(sighting);
    _sightings.insert(0, valid);
  }

  @override
  Future<void> setNickname(String nickname) async {
    final value = nickname.trim();
    if (value.isEmpty) {
      throw const AppFailure(FailureKind.validation, 'Digite um apelido.');
    }
    _nickname = value;
  }
}
