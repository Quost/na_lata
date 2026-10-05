import 'clients/app_failure.dart';
import 'clients/backend_client.dart';
import '../core/contracts.dart';
import '../core/models.dart';

const reviewCommentMaxLength = 500;

/// Colunas lidas em reviews; o apelido vem da relação com profiles.
const reviewColumns =
    'id, barcode, user_id, rating, comment, created_at, profiles(nickname)';

/// Validação do app antes de gravar (o banco mantém as mesmas constraints).
/// Retorna o rascunho normalizado, com comentário sem espaços nas pontas.
ReviewDraft validateReviewDraft(ReviewDraft draft) {
  final barcode = draft.barcode.trim();
  if (barcode.isEmpty) {
    throw const AppFailure(
      FailureKind.validation,
      'Informe o produto da avaliação.',
    );
  }
  if (draft.rating < 1 || draft.rating > 5) {
    throw const AppFailure(
      FailureKind.validation,
      'Escolha uma nota de 1 a 5.',
    );
  }
  final comment = draft.comment.trim();
  // O banco conta caracteres (code points), não unidades UTF-16.
  if (comment.runes.length > reviewCommentMaxLength) {
    throw const AppFailure(
      FailureKind.validation,
      'O comentário pode ter no máximo $reviewCommentMaxLength caracteres.',
    );
  }
  return ReviewDraft(barcode: barcode, rating: draft.rating, comment: comment);
}

/// Converte uma linha de reviews com `profiles(nickname)` em [Review].
Review reviewFromRow(Map<String, dynamic> row) {
  final id = row['id'];
  final barcode = row['barcode'];
  final userId = row['user_id'];
  final rating = row['rating'];
  final createdAt = DateTime.tryParse('${row['created_at']}');
  if (id is! String ||
      barcode is! String ||
      userId is! String ||
      rating is! int ||
      createdAt == null) {
    throw const AppFailure(
      FailureKind.invalidResponse,
      'Resposta inesperada ao ler avaliações.',
    );
  }
  final profile = row['profiles'];
  final nickname = profile is Map ? profile['nickname'] : null;
  return Review(
    id: id,
    barcode: barcode,
    userId: userId,
    nickname: nickname is String && nickname.trim().isNotEmpty
        ? nickname
        : 'Colega',
    rating: rating,
    comment: row['comment'] is String ? row['comment'] as String : '',
    createdAt: createdAt,
  );
}

class SupabaseReviews implements ReviewRepository {
  SupabaseReviews(this.client);
  final BackendClient client;

  @override
  Future<List<Review>> forProduct(String barcode) async {
    final rows = await client.request(
      (db) => db
          .from('reviews')
          .select(reviewColumns)
          .eq('barcode', barcode.trim())
          .order('created_at', ascending: false),
    );
    return rows.map(reviewFromRow).toList();
  }

  @override
  Future<List<Review>> mine() async {
    final userId = client.requireUserId;
    final rows = await client.request(
      (db) => db
          .from('reviews')
          .select(reviewColumns)
          .eq('user_id', userId)
          .order('created_at', ascending: false),
    );
    return rows.map(reviewFromRow).toList();
  }

  @override
  Future<void> save(ReviewDraft draft) async {
    final valid = validateReviewDraft(draft);
    final userId = client.requireUserId;
    // Sem id/created_at/updated_at: o banco gera e o trigger preserva.
    final rows = await client.request(
      (db) => db
          .from('reviews')
          .upsert({
            'barcode': valid.barcode,
            'user_id': userId,
            'rating': valid.rating,
            'comment': valid.comment,
          }, onConflict: 'barcode,user_id')
          .select('id'),
    );
    if (rows.isEmpty) {
      throw const AppFailure(
        FailureKind.unavailable,
        'A avaliação não foi confirmada. Consulte suas avaliações antes de tentar novamente.',
      );
    }
  }

  @override
  Future<void> delete(String reviewId) async {
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db.from('reviews').delete().eq('id', reviewId).select('id'),
      ),
    );
    if (rows.isEmpty) {
      throw const AppFailure(
        FailureKind.unavailable,
        'Avaliação não encontrada.',
      );
    }
  }
}
