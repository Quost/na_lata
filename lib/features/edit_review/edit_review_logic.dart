import '../../core/models.dart';
import '../../core/ui_format.dart';

/// Avaliação da sessão para o produto, vinda de `mine()`; null se não houver.
/// Se o repositório devolver mais de uma, usa a mais recente.
Review? findMyReview(List<Review> mine, String barcode) {
  Review? found;
  for (final review in mine) {
    if (review.barcode != barcode.trim()) continue;
    if (found == null || review.createdAt.isAfter(found.createdAt)) {
      found = review;
    }
  }
  return found;
}

/// Há algo para salvar? Compara com o comentário sem espaços nas pontas.
bool hasChanges(
  Review original, {
  required int? rating,
  required String comment,
}) => rating != original.rating || comment.trim() != original.comment.trim();

/// Data curta em pt-BR (delegada ao util compartilhado).
String formatReviewDate(DateTime date) => formatShortDate(date);
