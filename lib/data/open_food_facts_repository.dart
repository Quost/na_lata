import '../core/contracts.dart';
import 'clients/app_failure.dart';
import 'clients/json_api_client.dart';
import '../core/models.dart';

const offProductNameFallback = 'Produto sem nome';
const offFields =
    'code,product_name,brands,categories_tags,image_front_url,'
    'product_quantity,product_quantity_unit,quantity';

final _offBarcode = RegExp(r'^\d{8,14}$');

/// Código aceito na URL do OFF: 8 a 14 dígitos, mantido como texto.
bool isOffBarcode(String barcode) => _offBarcode.hasMatch(barcode);

class HttpOpenFoodFactsRepository implements OpenFoodFactsRepository {
  HttpOpenFoodFactsRepository({JsonApiClient? api})
    : api = api ?? JsonApiClient();
  final JsonApiClient api;
  @override
  Future<Product?> lookup(String barcode) async {
    if (!isOffBarcode(barcode)) {
      throw const AppFailure(
        FailureKind.validation,
        'Informe um código de barras de 8 a 14 dígitos.',
      );
    }
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$barcode.json',
      {'fields': offFields},
    );
    // O OFF responde produto inexistente com HTTP 404 e corpo {"status":0}.
    final json = await api.getObject(uri, acceptStatus: const {404});
    return parseOffProduct(json, barcode);
  }
}

/// Converte a resposta de /api/v2/product/{barcode}.json em [Product].
///
/// status 0 é produto inexistente (null); qualquer outra estrutura inesperada é
/// resposta inválida. Mantém o [barcode] consultado, pois o OFF pode devolver
/// `code` normalizado (ex.: UPC de 12 dígitos com zero à esquerda).
Product? parseOffProduct(Map<String, dynamic> json, String barcode) {
  final status = json['status'];
  if (status == 0) return null;
  final product = json['product'];
  if (status != 1 || product is! Map<String, dynamic>) {
    throw const AppFailure(
      FailureKind.invalidResponse,
      'O serviço retornou dados inválidos.',
    );
  }
  return Product(
    barcode: barcode,
    name: _text(product['product_name']) ?? offProductNameFallback,
    brand: _firstBrand(product['brands']),
    category: _firstTag(product['categories_tags']),
    imageUrl: _text(product['image_front_url']),
    packageSize: parseOffPackageSize(product),
  );
}

/// Texto sem espaços nas bordas; vazio ou tipo inesperado vira null.
String? _text(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// Primeira marca de "Marca A, Marca B", normalizada em minúsculas.
String? _firstBrand(Object? value) =>
    _text(value)?.split(',').map(_text).nonNulls.firstOrNull?.toLowerCase();

String? _firstTag(Object? value) =>
    value is List ? value.map(_text).nonNulls.firstOrNull : null;

final _offTextQuantity = RegExp(
  r'^(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l)$',
  caseSensitive: false,
);
final _offPlainNumber = RegExp(r'^\d+(?:\.\d+)?$');

/// "1.000" / "1,500": separador seguido de exatamente 3 dígitos pode ser
/// milhar (en/pt) ou decimal; sem como saber, fica desconhecido.
final _ambiguousThousands = RegExp(r'^[1-9]\d*[.,]\d{3}$');

/// Extrai o tamanho da embalagem de `product` (parte interna da resposta OFF).
///
/// Função pura, nunca lança. Retorna null (desconhecido) quando não há dado
/// confiável:
/// 1. `product_quantity` + `product_quantity_unit` presentes: usa somente eles.
///    Se estiverem inválidos (zero, negativo, não numérico, unidade ausente ou
///    fora de g/kg/ml/l), o resultado é desconhecido e o texto não é usado
///    para "adivinhar" no lugar.
/// 2. Sem campo estruturado: aceita só `quantity` no formato exato
///    "<número> <g|kg|ml|l>". Multiembalagem ("6 x 330 ml"), unidades como
///    "un" ou "cl", textos com mais conteúdo e números ambíguos viram null.
PackageSize? parseOffPackageSize(Map<String, dynamic> product) {
  final structured = product['product_quantity'];
  if (_isPresent(structured)) {
    return PackageSize.tryCreate(
      _plainNumber(structured),
      PackageUnit.fromSymbol(product['product_quantity_unit']),
      PackageSizeSource.offStructured,
    );
  }
  return _sizeFromText(product['quantity']);
}

bool _isPresent(Object? value) =>
    value != null && !(value is String && value.trim().isEmpty);

/// Número vindo do JSON como num ou texto simples ("500", "12.5").
num? _plainNumber(Object? value) {
  if (value is num) return value;
  if (value is! String) return null;
  final text = value.trim();
  return _offPlainNumber.hasMatch(text) ? double.parse(text) : null;
}

PackageSize? _sizeFromText(Object? value) {
  if (value is! String) return null;
  final match = _offTextQuantity.firstMatch(value.trim());
  if (match == null) return null;
  final number = match.group(1)!;
  if (_ambiguousThousands.hasMatch(number)) return null;
  return PackageSize.tryCreate(
    double.parse(number.replaceAll(',', '.')),
    PackageUnit.fromSymbol(match.group(2)),
    PackageSizeSource.offText,
  );
}
