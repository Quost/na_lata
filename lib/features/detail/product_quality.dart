import '../../core/models.dart';
import '../../data/open_food_facts_repository.dart' show isOffBarcode;

/// Campo essencial que pode faltar na ficha. Não há nota de qualidade: a ficha
/// só informa, de forma específica, o que está ausente.
enum MissingField {
  image('foto'),
  brand('marca'),
  quantity('quantidade');

  const MissingField(this.label);
  final String label;
}

/// Campos essenciais ausentes de [product], sempre na ordem foto, marca,
/// quantidade. Texto vazio ou só com espaços conta como ausente; tamanho
/// desconhecido ([Product.packageSize] nulo) conta como quantidade ausente.
List<MissingField> missingEssentialFields(Product product) => [
  if (_isBlank(product.imageUrl)) MissingField.image,
  if (_isBlank(product.brand)) MissingField.brand,
  if (product.packageSize == null) MissingField.quantity,
];

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

/// Página de edição do produto no Open Food Facts, ou null quando não há como
/// afirmar que o produto veio de lá.
///
/// O link só existe se [sourceUrl] for HTTPS, sem credenciais e de um host do
/// openfoodfacts.org, e se [barcode] for um código válido do OFF. Produto
/// manual, antigo ou com URL de outro site resulta em null: nunca se inventa
/// link. O destino usa host fixo e só o código de barras: nenhum dado do
/// usuário é enviado.
Uri? offEditUri({required String barcode, required String? sourceUrl}) {
  if (!isOffBarcode(barcode)) return null;
  final raw = sourceUrl?.trim();
  if (raw == null || raw.isEmpty) return null;
  final source = Uri.tryParse(raw);
  if (source == null ||
      source.scheme != 'https' ||
      source.userInfo.isNotEmpty ||
      !_isOffHost(source.host)) {
    return null;
  }
  return Uri.https('world.openfoodfacts.org', '/cgi/product.pl', {
    'type': 'edit',
    'code': barcode,
  });
}

bool _isOffHost(String host) {
  final name = host.toLowerCase();
  return name == 'openfoodfacts.org' || name.endsWith('.openfoodfacts.org');
}
