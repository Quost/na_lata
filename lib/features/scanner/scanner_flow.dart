import '../../core/contracts.dart';
import '../../core/models.dart';

final _barcodePattern = RegExp(r'^\d{8,14}$');

/// Retorna o código como texto (preservando zeros) ou null se não tiver
/// de 8 a 14 dígitos. Códigos `demo-*` nunca são aceitos.
String? normalizeBarcode(String? raw) {
  final value = raw?.trim() ?? '';
  return _barcodePattern.hasMatch(value) ? value : null;
}

/// Garante que uma sessão de câmera entregue um único código.
class ScanGate {
  bool _done = false;
  bool get done => _done;

  /// Primeiro código válido da leitura; null se inválido ou já aceito antes.
  String? accept(Iterable<String?> rawValues) {
    if (_done) return null;
    for (final raw in rawValues) {
      final code = normalizeBarcode(raw);
      if (code != null) {
        _done = true;
        return code;
      }
    }
    return null;
  }
}

/// Catálogo primeiro; se ausente, consulta OFF e importa.
/// Retorna null quando o produto não existe em nenhum dos dois.
Future<Product?> resolveBarcode(
  String barcode, {
  required ProductRepository products,
  required OpenFoodFactsRepository openFoodFacts,
}) async {
  final existing = await products.byBarcode(barcode);
  if (existing != null) return existing;
  final external = await openFoodFacts.lookup(barcode);
  if (external == null) return null;
  await products.importProduct(external);
  return await products.byBarcode(barcode) ?? external;
}
