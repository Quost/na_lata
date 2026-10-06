import '../../data/clients/app_failure.dart';

const replyBodyMaxLength = 500;
const replyPageSize = 20;
const replyPageSizeMax = 50;
const replyAccountRequiredMessage =
    'Só contas confirmadas podem responder avaliações.';
const replyNotFoundMessage = 'Resposta não encontrada. Atualize a tela.';

/// Resposta de uma camada a uma avaliação. Não existe resposta de resposta.
class Reply {
  const Reply({
    required this.id,
    required this.reviewId,
    required this.authorId,
    required this.authorNickname,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, reviewId, authorId, authorNickname;

  /// Texto original, como foi gravado. A moderação de exibição não o altera.
  final String body;
  final DateTime createdAt, updatedAt;

  bool get edited => updatedAt.isAfter(createdAt);
}

class ReplyPage {
  const ReplyPage(this.items, {required this.hasMore});
  final List<Reply> items;
  final bool hasMore;
}

/// Mesmas regras do banco: 1–500 caracteres e não só espaços.
/// Devolve o texto sem alteração; quem mascara é a exibição.
String validateReplyBody(String body) {
  if (body.trim().isEmpty) {
    throw const AppFailure(FailureKind.validation, 'Escreva uma resposta.');
  }
  if (body.runes.length > replyBodyMaxLength) {
    throw const AppFailure(
      FailureKind.validation,
      'A resposta pode ter até $replyBodyMaxLength caracteres.',
    );
  }
  return body;
}

/// `profiles(nickname)` traz o apelido sem duplicá-lo na tabela de respostas.
const replyColumns =
    'id, review_id, author_id, body, created_at, updated_at, profiles(nickname)';

Reply replyFromRow(Map<String, dynamic> row) {
  final profile = row['profiles'];
  String? nickname;
  if (profile is Map<String, dynamic>) {
    nickname = profile['nickname'] as String?;
  } else if (profile is List && profile.isNotEmpty) {
    nickname = (profile.first as Map<String, dynamic>)['nickname'] as String?;
  }
  return Reply(
    id: row['id'] as String,
    reviewId: row['review_id'] as String,
    authorId: row['author_id'] as String,
    authorNickname: nickname ?? 'Colega',
    body: row['body'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
