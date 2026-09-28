import 'clients/backend_client.dart';
import 'clients/app_failure.dart';
import '../core/contracts.dart';
import '../core/models.dart';

class SupabaseReviews implements ReviewRepository {
  SupabaseReviews(this.client);
  final BackendClient client;
  @override
  Future<List<Review>> forProduct(String barcode) async {
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db
            .from('reviews')
            .select('*, profiles(nickname)')
            .eq('barcode', barcode)
            .order('created_at', ascending: false),
      ),
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Review>> mine() async {
    final userId = client.requireUserId;
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db
            .from('reviews')
            .select('*, profiles(nickname)')
            .eq('user_id', userId)
            .order('created_at', ascending: false),
      ),
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(ReviewDraft draft) async {
    if (draft.rating < 1 || draft.rating > 5 || draft.comment.length > 500) {
      throw const AppFailure(
        FailureKind.validation,
        'Nota ou comentário inválido.',
      );
    }
    await client.request<void>(
      (db) => db.from('reviews').upsert({
        'barcode': draft.barcode,
        'user_id': client.requireUserId,
        'rating': draft.rating,
        'comment': draft.comment.trim(),
      }, onConflict: 'barcode,user_id'),
    );
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

  Review _fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return Review(
      id: row['id'] as String,
      barcode: row['barcode'] as String,
      userId: row['user_id'] as String,
      nickname: profile?['nickname'] as String? ?? 'Colega',
      rating: row['rating'] as int,
      comment: row['comment'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
