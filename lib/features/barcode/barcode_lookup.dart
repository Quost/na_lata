import '../../core/contracts.dart';
import '../../core/models.dart';

const barcodeMinLength = 8;
const barcodeMaxLength = 14;
final _digitsOnly = RegExp(r'^\d+$');

/// Remove espaços das bordas. O código continua texto para preservar zeros.
String normalizeBarcode(String input) => input.trim();

/// Retorna a mensagem de erro para o campo ou null quando o código é válido.
String? validateBarcode(String? input) {
  final code = normalizeBarcode(input ?? '');
  if (code.isEmpty) return 'Digite o código de barras.';
  if (!_digitsOnly.hasMatch(code)) return 'Use apenas números.';
  if (code.length < barcodeMinLength || code.length > barcodeMaxLength) {
    return 'O código deve ter de $barcodeMinLength a $barcodeMaxLength '
        'dígitos (você digitou ${code.length}).';
  }
  return null;
}

sealed class BarcodeLookupResult {
  const BarcodeLookupResult();
}

class BarcodeFound extends BarcodeLookupResult {
  const BarcodeFound(this.product, {required this.imported});
  final Product product;

  /// true quando veio do Open Food Facts e acabou de entrar no catálogo.
  final bool imported;
}

class BarcodeNotFound extends BarcodeLookupResult {
  const BarcodeNotFound(this.barcode);
  final String barcode;
}

/// Consulta o catálogo primeiro; se ausente, busca no OFF e importa.
/// Erros dos repositórios são propagados para a UI decidir a mensagem.
class BarcodeLookup {
  const BarcodeLookup({required this.products, required this.openFoodFacts});
  final ProductRepository products;
  final OpenFoodFactsRepository openFoodFacts;

  Future<BarcodeLookupResult> find(String input) async {
    final code = normalizeBarcode(input);
    // Garante que códigos fictícios (demo-*) ou inválidos nunca vão ao OFF.
    final invalid = validateBarcode(code);
    if (invalid != null) throw ArgumentError.value(input, 'input', invalid);

    final existing = await products.byBarcode(code);
    if (existing != null) return BarcodeFound(existing, imported: false);

    final external = await openFoodFacts.lookup(code);
    if (external == null) return BarcodeNotFound(code);

    await products.importProduct(external);
    return BarcodeFound(external, imported: true);
  }
}
