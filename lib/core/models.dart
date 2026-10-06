class Product {
  const Product({
    required this.barcode,
    required this.name,
    this.brand,
    this.category,
    this.imageUrl,
    this.isDemo = false,
    this.source,
    this.sourceUrl,
    this.sourceFetchedAt,
    this.cachedAt,
  });
  final String barcode;
  final String name;
  final String? brand, category, imageUrl;
  final bool isDemo;

  /// Origem dos dados (ver [ProductSource]); null em produtos anteriores ao
  /// registro de origem, que não recebem data nem fonte retroativas.
  final String? source;

  /// Página do produto na fonte; só é exibida se passar em [safeSourceUri].
  final String? sourceUrl;

  /// Momento em que a fonte foi consultada; null quando desconhecido.
  final DateTime? sourceFetchedAt;

  /// Momento em que a ficha foi gravada no cache offline; null se for live.
  final DateTime? cachedAt;
}

class Review {
  const Review({
    required this.id,
    required this.barcode,
    required this.userId,
    required this.nickname,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
  final String id, barcode, userId, nickname, comment;
  final int rating;
  final DateTime createdAt;
}

class ReviewDraft {
  const ReviewDraft({
    required this.barcode,
    required this.rating,
    this.comment = '',
  });
  final String barcode, comment;
  final int rating;
}

class ProductQuery {
  const ProductQuery({this.text = '', this.brand, this.category});
  final String text;
  final String? brand, category;
}

/// Marca do diretório; [key] é o brand_key dos produtos, sem bordas.
class Brand {
  const Brand({required this.key, required this.productCount});
  final String key;
  final int productCount;
}

/// Página de marcas; [nextAfter] nulo indica a última página.
class BrandPage {
  const BrandPage({required this.items, this.nextAfter});
  final List<Brand> items;
  final String? nextAfter;
}

class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.histogram,
  });
  final double? average;
  final int count;
  final Map<int, int> histogram;
}

class Sighting {
  const Sighting({
    required this.barcode,
    required this.store,
    required this.city,
  });
  final String barcode, store, city;
}
