import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../clients/app_failure.dart';

/// Decorator para fazer cache das últimas 50 fichas.
///
/// Comportamento:
/// - Online: salva o resultado de sucesso.
/// - Offline (falha de rede/timeout): carrega automaticamente do cache se existir.
/// - Outros erros: repassa a exceção.
class CachedProductRepository implements ProductRepository {
  CachedProductRepository(this._delegate, this._prefs);
  final ProductRepository _delegate;
  final SharedPreferences _prefs;

  static const _maxItems = 50;
  static const _keysListKey = 'cached_product_keys';

  @override
  Future<List<Product>> search(ProductQuery query) {
    // Não cacheamos resultados de busca.
    return _delegate.search(query);
  }

  @override
  Future<void> importProduct(Product product) {
    // Não lidamos com gravação offline no cache de leitura.
    return _delegate.importProduct(product);
  }

  @override
  Future<Product?> byBarcode(String barcode) async {
    try {
      final product = await _delegate.byBarcode(barcode);
      if (product != null) {
        await _saveToCache(product);
      }
      return product;
    } on AppFailure catch (e) {
      if (e.kind == FailureKind.network || e.kind == FailureKind.timeout) {
        final cached = _loadFromCache(barcode);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  Future<void> _saveToCache(Product product) async {
    final key = 'product_cache_${product.barcode}';
    final data = jsonEncode({
      'barcode': product.barcode,
      'name': product.name,
      'brand': product.brand,
      'category': product.category,
      'imageUrl': product.imageUrl,
      'isDemo': product.isDemo,
      'source': product.source,
      'sourceUrl': product.sourceUrl,
      'sourceFetchedAt': product.sourceFetchedAt?.toIso8601String(),
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
    });

    await _prefs.setString(key, data);
    _updateKeysLRU(key);
  }

  void _updateKeysLRU(String key) {
    final keys = _prefs.getStringList(_keysListKey) ?? <String>[];
    keys.remove(key);
    keys.add(key);

    while (keys.length > _maxItems) {
      final oldest = keys.removeAt(0);
      _prefs.remove(oldest);
    }
    _prefs.setStringList(_keysListKey, keys);
  }

  Product? _loadFromCache(String barcode) {
    final key = 'product_cache_$barcode';
    final raw = _prefs.getString(key);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Product(
        barcode: map['barcode'] as String,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        category: map['category'] as String?,
        imageUrl: map['imageUrl'] as String?,
        isDemo: map['isDemo'] as bool? ?? false,
        source: map['source'] as String?,
        sourceUrl: map['sourceUrl'] as String?,
        sourceFetchedAt: map['sourceFetchedAt'] != null
            ? DateTime.parse(map['sourceFetchedAt'] as String)
            : null,
        cachedAt: map['cachedAt'] != null
            ? DateTime.parse(map['cachedAt'] as String)
            : null,
      );
    } catch (_) {
      // Esquema inválido: descarta.
      _prefs.remove(key);
      return null;
    }
  }
}
