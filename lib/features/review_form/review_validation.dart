import '../../core/models.dart';

const maxCommentLength = 500;

/// Nota inteira de 1 a 5 é obrigatória.
String? validateRating(int? rating) => rating == null
    ? 'Escolha uma nota de 1 a 5.'
    : rating < 1 || rating > 5
    ? 'A nota deve ser de 1 a 5.'
    : null;

/// Comentário é opcional; conta o texto sem espaços nas pontas.
String? validateComment(String comment) =>
    comment.trim().length > maxCommentLength
    ? 'O comentário pode ter até $maxCommentLength caracteres.'
    : null;

/// Monta o rascunho somente com dados válidos; senão lança ArgumentError.
ReviewDraft buildDraft({
  required String barcode,
  required int? rating,
  String comment = '',
}) {
  final error = validateRating(rating) ?? validateComment(comment);
  if (error != null) throw ArgumentError(error);
  return ReviewDraft(
    barcode: barcode,
    rating: rating!,
    comment: comment.trim(),
  );
}
