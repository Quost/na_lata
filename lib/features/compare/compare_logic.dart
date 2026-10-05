import '../../core/contracts.dart';
import '../../core/models.dart';

/// Comparação sempre entre exatamente dois produtos.
const maxComparedProducts = 2;

/// Mesma assinatura de `summarizeReviews` (T10), injetável nos testes.
typedef ReviewSummarizer = RatingSummary Function(List<Review> reviews);

/// Produto escolhido em cada posição da comparação.
///
/// Só existem duas posições, então o máximo de dois selecionados é garantido
/// pela estrutura; [pick] impede que o mesmo produto ocupe as duas.
class CompareSelection {
  const CompareSelection({this.first, this.second});
  final String? first, second;

  List<String> get barcodes => [?first, ?second];
  bool get isComplete => first != null && second != null;

  /// Retorna a mensagem de erro quando [barcode] já está na outra posição.
  String? duplicateError(int slot, String? barcode) {
    final other = slot == 0 ? second : first;
    if (barcode != null && barcode == other) {
      return 'Escolha um produto diferente do outro lado.';
    }
    return null;
  }

  /// Nova seleção com [barcode] na posição [slot] (0 ou 1).
  /// Lança [ArgumentError] para posição inválida ou produto repetido.
  CompareSelection pick(int slot, String? barcode) {
    if (slot < 0 || slot >= maxComparedProducts) {
      throw RangeError.range(slot, 0, maxComparedProducts - 1, 'slot');
    }
    final error = duplicateError(slot, barcode);
    if (error != null) throw ArgumentError(error);
    return slot == 0
        ? CompareSelection(first: barcode, second: second)
        : CompareSelection(first: first, second: barcode);
  }

  /// Primeiros dois códigos distintos de [barcodes], na ordem recebida.
  factory CompareSelection.from(Iterable<String> barcodes) {
    final distinct = barcodes.toSet().take(maxComparedProducts).toList();
    return CompareSelection(
      first: distinct.isNotEmpty ? distinct[0] : null,
      second: distinct.length > 1 ? distinct[1] : null,
    );
  }
}

class ComparedProduct {
  const ComparedProduct({required this.product, required this.summary});
  final Product product;
  final RatingSummary summary;
}

/// Busca as avaliações de cada produto no repositório e resume com
/// [summarize]. Recusa lista com tamanho diferente de dois ou repetida.
Future<List<ComparedProduct>> loadComparison({
  required ReviewRepository reviews,
  required List<Product> products,
  required ReviewSummarizer summarize,
}) async {
  if (products.length != maxComparedProducts) {
    throw ArgumentError('Selecione exatamente dois produtos.');
  }
  if (products[0].barcode == products[1].barcode) {
    throw ArgumentError('Não é possível comparar o mesmo produto.');
  }
  final lists = await Future.wait(
    products.map((p) => reviews.forProduct(p.barcode)),
  );
  return [
    for (var i = 0; i < products.length; i++)
      ComparedProduct(product: products[i], summary: summarize(lists[i])),
  ];
}

/// Frase-resumo: quem tem a maior média, empate ou falta de notas.
String compareVerdict(ComparedProduct a, ComparedProduct b) {
  final avgA = a.summary.average, avgB = b.summary.average;
  if (avgA == null && avgB == null) return 'Nenhum dos dois tem avaliações.';
  if (avgA == null) return 'Só ${b.product.name} tem avaliações.';
  if (avgB == null) return 'Só ${a.product.name} tem avaliações.';
  if (avgA == avgB) return 'Empate na média: ${formatAverage(avgA)}.';
  final best = avgA > avgB ? a : b;
  return '${best.product.name} tem a maior média.';
}

/// Média com uma casa e vírgula decimal, ou texto para ausência de notas.
String formatAverage(double? average) => average == null
    ? 'Sem avaliações'
    : '${average.toStringAsFixed(1).replaceAll('.', ',')} de 5';

String formatCount(int count) => switch (count) {
  0 => 'Nenhuma avaliação',
  1 => '1 avaliação',
  _ => '$count avaliações',
};
