import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/replies/reply_models.dart';
import 'clients/app_failure.dart';
import 'clients/backend_client.dart';

/// CON01 — respostas às avaliações. Não toca em reviews: média e contagem não mudam.
abstract interface class ReplyRepository {
  /// Respostas da avaliação, mais antigas primeiro (created_at, depois id).
  /// [offset] é a quantidade de respostas já carregadas.
  Future<ReplyPage> page(
    String reviewId, {
    int limit = replyPageSize,
    int offset = 0,
  });

  /// Exige conta confirmada. Guarda o texto original, sem moderação.
  Future<Reply> create(String reviewId, String body);

  /// Só o autor edita. Falha se nenhuma resposta própria foi alterada.
  Future<Reply> update(String replyId, String body);

  /// Só o autor exclui. Falha se nenhuma resposta própria foi apagada.
  Future<void> delete(String replyId);
}

class SupabaseReplyRepository implements ReplyRepository {
  SupabaseReplyRepository(this.client);
  final BackendClient client;

  @override
  Future<ReplyPage> page(
    String reviewId, {
    int limit = replyPageSize,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > replyPageSizeMax || offset < 0) {
      throw const AppFailure(FailureKind.validation, 'Página inválida.');
    }
    // Pede uma linha a mais só para saber se existe próxima página.
    final rows = await client.request(
      (db) => db
          .from('review_replies')
          .select(replyColumns)
          .eq('review_id', reviewId)
          .order('created_at', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + limit),
    );
    final items = rows.map(replyFromRow).toList();
    final hasMore = items.length > limit;
    return ReplyPage(
      hasMore ? items.sublist(0, limit) : items,
      hasMore: hasMore,
    );
  }

  @override
  Future<Reply> create(String reviewId, String body) async {
    final text = validateReplyBody(body);
    final userId = client.requireUserId; // nunca aceitar author_id da UI
    final row = await _write(
      (db) => db
          .from('review_replies')
          .insert({'review_id': reviewId, 'author_id': userId, 'body': text})
          .select(replyColumns)
          .single(),
    );
    return replyFromRow(row);
  }

  @override
  Future<Reply> update(String replyId, String body) async {
    final text = validateReplyBody(body);
    final userId = client.requireUserId;
    final rows = await _write(
      (db) => db
          .from('review_replies')
          .update({'body': text})
          .eq('id', replyId)
          .eq('author_id', userId)
          .select(replyColumns),
    );
    // UPDATE que afeta 0 linhas não lança erro: conferir o retorno.
    if (rows.isEmpty) {
      throw const AppFailure(FailureKind.unavailable, replyNotFoundMessage);
    }
    return replyFromRow(rows.first);
  }

  @override
  Future<void> delete(String replyId) async {
    final userId = client.requireUserId;
    final rows = await client.request(
      (db) => db
          .from('review_replies')
          .delete()
          .eq('id', replyId)
          .eq('author_id', userId)
          .select('id'),
    );
    if (rows.isEmpty) {
      throw const AppFailure(FailureKind.unavailable, replyNotFoundMessage);
    }
  }

  /// Escritas novas exigem conta confirmada; a RLS responde 42501 ao visitante.
  Future<T> _write<T>(Future<T> Function(SupabaseClient db) action) async {
    try {
      return await client.request(action);
    } on AppFailure catch (error) {
      if (error.kind == FailureKind.unauthorized) {
        throw const AppFailure(
          FailureKind.unauthorized,
          replyAccountRequiredMessage,
        );
      }
      rethrow;
    }
  }
}
