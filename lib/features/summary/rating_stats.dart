import '../../core/models.dart';

/// Estatísticas de avaliação para um produto específico.
///
/// Diferente de [RatingSummary], que é calculado inline, [RatingStats] inclui
/// o barcode para uso em consultas em lote (rankings, busca com nota).
class RatingStats {
  const RatingStats({
    required this.barcode,
    required this.average,
    required this.count,
    required this.histogram,
  });

  final String barcode;

  /// Média aritmética das notas. Null quando não há avaliações.
  /// Não arredondar antes de ordenar — a precisão é preservada para ranking.
  final double? average;

  /// Total de avaliações. Cada review conta uma única vez.
  final int count;

  /// Contagem por estrela (1–5). Chaves ausentes significam zero.
  final Map<int, int> histogram;
}

/// Calcula [RatingStats] para um único [barcode] a partir de uma lista de
/// [reviews] já filtradas para esse produto.
///
/// Mantém a mesma lógica de [summarizeReviews], mas inclui o barcode no
/// resultado para uso em lote.
RatingStats computeStats(String barcode, List<Review> reviews) {
  final histogram = <int, int>{for (var star = 1; star <= 5; star++) star: 0};
  var sum = 0;
  for (final review in reviews) {
    final rating = review.rating;
    if (rating < 1 || rating > 5) {
      throw RangeError.range(rating, 1, 5, 'rating');
    }
    histogram[rating] = histogram[rating]! + 1;
    sum += rating;
  }
  return RatingStats(
    barcode: barcode,
    average: reviews.isEmpty ? null : sum / reviews.length,
    count: reviews.length,
    histogram: Map.unmodifiable(histogram),
  );
}

/// Calcula [RatingStats] para vários produtos em uma **única passagem** pela
/// lista de reviews, evitando o problema N+1.
///
/// Retorna um mapa de barcode → stats. Barcodes sem avaliação recebem
/// stats com média null e quantidade 0 (não são omitidos).
///
/// Se [barcodes] for null, extrai os barcodes automaticamente das reviews.
Map<String, RatingStats> computeStatsBatch(
  List<Review> allReviews, {
  List<String>? barcodes,
}) {
  // Agrupar reviews por barcode em uma passagem.
  final grouped = <String, List<Review>>{};
  for (final review in allReviews) {
    (grouped[review.barcode] ??= []).add(review);
  }

  // Garantir que todos os barcodes solicitados estejam no resultado.
  final keys = barcodes ?? grouped.keys.toList();

  return {
    for (final barcode in keys)
      barcode: computeStats(barcode, grouped[barcode] ?? []),
  };
}
