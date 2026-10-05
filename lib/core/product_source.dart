/// Identificadores gravados em `products.source`.
abstract final class ProductSource {
  static const openFoodFacts = 'open_food_facts';
}

/// Hosts autorizados para o link de origem.
const _allowedSourceHosts = {'openfoodfacts.org'};

/// Devolve [raw] como [Uri] somente se for HTTPS, sem credenciais e de um host
/// permitido (ou subdomínio dele); caso contrário null.
Uri? safeSourceUri(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final allowed = _allowedSourceHosts.any(
    (allowedHost) => host == allowedHost || host.endsWith('.$allowedHost'),
  );
  return allowed ? uri : null;
}

/// Página pública do produto no Open Food Facts.
String openFoodFactsProductUrl(String barcode) =>
    'https://world.openfoodfacts.org/product/$barcode';
