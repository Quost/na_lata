import 'clients/app_failure.dart';
import 'clients/backend_client.dart';

/// Limites do motivo da decisão (mesmo check do banco).
const moderationReasonMinLength = 3;
const moderationReasonMaxLength = 500;

/// Colunas da fila: denúncia + avaliação denunciada + apelido do autor.
const reportQueueColumns =
    'id, review_id, reason, status, created_at, '
    'reviews(barcode, rating, comment, visibility, profiles(nickname))';

enum ReportStatus { pending, dismissed, actioned }

/// Lê o status do banco; null quando desconhecido.
ReportStatus? reportStatusFromName(Object? value) {
  for (final status in ReportStatus.values) {
    if (status.name == value) return status;
  }
  return null;
}

/// Resultado de uma decisão: aplicada agora ou já estava nesse estado.
enum ModerationOutcome { applied, unchanged }

/// Denúncia na fila do moderador, com a avaliação denunciada.
class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.reviewId,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.barcode,
    required this.rating,
    required this.comment,
    required this.authorNickname,
    required this.reviewHidden,
  });

  final String id, reviewId, reason, barcode, comment, authorNickname;
  final ReportStatus status;
  final DateTime createdAt;
  final int rating;
  final bool reviewHidden;

  ModerationReport copyWith({ReportStatus? status, bool? reviewHidden}) =>
      ModerationReport(
        id: id,
        reviewId: reviewId,
        reason: reason,
        status: status ?? this.status,
        createdAt: createdAt,
        barcode: barcode,
        rating: rating,
        comment: comment,
        authorNickname: authorNickname,
        reviewHidden: reviewHidden ?? this.reviewHidden,
      );
}

/// Operações do moderador. A permissão é sempre conferida no servidor;
/// o cliente só melhora a mensagem.
abstract interface class ModerationRepository {
  Future<bool> isModerator();
  Future<List<ModerationReport>> pendingReports({int limit = 50});
  Future<ModerationOutcome> setReviewHidden(
    String reviewId, {
    required bool hidden,
    required String reason,
  });
  Future<ModerationOutcome> dismissReport(String reportId, String reason);
}

/// Normaliza o motivo e valida o tamanho antes de chamar o banco.
String validateModerationReason(String reason) {
  final value = reason.trim();
  final length = value.runes.length;
  if (length < moderationReasonMinLength ||
      length > moderationReasonMaxLength) {
    throw const AppFailure(
      FailureKind.validation,
      'Informe o motivo da decisão ($moderationReasonMinLength a '
      '$moderationReasonMaxLength caracteres).',
    );
  }
  return value;
}

/// Converte o retorno das funções `moderate_review`/`dismiss_report`.
ModerationOutcome interpretModerationResult(
  Object? value, {
  required String notFoundMessage,
}) => switch (value) {
  'ok' => ModerationOutcome.applied,
  'unchanged' => ModerationOutcome.unchanged,
  'not_found' => throw AppFailure(FailureKind.validation, notFoundMessage),
  _ => throw const AppFailure(
    FailureKind.invalidResponse,
    'Resposta inesperada do servidor de moderação.',
  ),
};

/// Converte uma linha de [reportQueueColumns] em [ModerationReport].
ModerationReport moderationReportFromRow(Map<String, dynamic> row) {
  final review = row['reviews'];
  final id = row['id'];
  final reviewId = row['review_id'];
  final reason = row['reason'];
  final status = reportStatusFromName(row['status']);
  final createdAt = DateTime.tryParse('${row['created_at']}');
  if (id is! String ||
      reviewId is! String ||
      reason is! String ||
      status == null ||
      createdAt == null ||
      review is! Map ||
      review['barcode'] is! String ||
      review['rating'] is! int) {
    throw const AppFailure(
      FailureKind.invalidResponse,
      'Resposta inesperada ao ler denúncias.',
    );
  }
  final profile = review['profiles'];
  final nickname = profile is Map ? profile['nickname'] : null;
  final comment = review['comment'];
  return ModerationReport(
    id: id,
    reviewId: reviewId,
    reason: reason,
    status: status,
    createdAt: createdAt,
    barcode: review['barcode'] as String,
    rating: review['rating'] as int,
    comment: comment is String ? comment : '',
    authorNickname: nickname is String && nickname.trim().isNotEmpty
        ? nickname
        : 'Colega',
    reviewHidden: review['visibility'] == 'hidden',
  );
}

const _notModerator = AppFailure(
  FailureKind.unauthorized,
  'Somente moderadores acessam a fila de denúncias.',
);

void _requireId(String id) {
  if (id.trim().isEmpty) {
    throw const AppFailure(FailureKind.validation, 'Item não informado.');
  }
}

class SupabaseModeration implements ModerationRepository {
  SupabaseModeration(this.client);
  final BackendClient client;

  @override
  Future<bool> isModerator() async {
    final value = await client.request<dynamic>(
      (db) async => await db.rpc('is_moderator'),
    );
    return value == true;
  }

  @override
  Future<List<ModerationReport>> pendingReports({int limit = 50}) async {
    // Sem este teste a RLS devolveria só as denúncias do próprio usuário.
    if (!await isModerator()) throw _notModerator;
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db
            .from('reports')
            .select(reportQueueColumns)
            .eq('status', ReportStatus.pending.name)
            .order('created_at')
            .limit(limit),
      ),
    );
    return rows.map(moderationReportFromRow).toList();
  }

  @override
  Future<ModerationOutcome> setReviewHidden(
    String reviewId, {
    required bool hidden,
    required String reason,
  }) async {
    _requireId(reviewId);
    final valid = validateModerationReason(reason);
    final result = await client.request<dynamic>(
      (db) async => await db.rpc(
        'moderate_review',
        params: {
          'p_review_id': reviewId,
          'p_hidden': hidden,
          'p_reason': valid,
        },
      ),
    );
    return interpretModerationResult(
      result,
      notFoundMessage: 'Avaliação não encontrada.',
    );
  }

  @override
  Future<ModerationOutcome> dismissReport(
    String reportId,
    String reason,
  ) async {
    _requireId(reportId);
    final valid = validateModerationReason(reason);
    final result = await client.request<dynamic>(
      (db) async => await db.rpc(
        'dismiss_report',
        params: {'p_report_id': reportId, 'p_reason': valid},
      ),
    );
    return interpretModerationResult(
      result,
      notFoundMessage: 'Denúncia não encontrada.',
    );
  }
}

/// Implementação em memória com as mesmas regras do banco, para testes e
/// para desenvolver a fila (MOD02) sem Supabase.
class InMemoryModeration implements ModerationRepository {
  InMemoryModeration({
    required this.moderator,
    List<ModerationReport> reports = const [],
  }) : _reports = [...reports];

  final bool moderator;
  final List<ModerationReport> _reports;

  /// Decisões registradas (ação e motivo), como a trilha do banco.
  final List<({String action, String targetId, String reason})> log = [];

  @override
  Future<bool> isModerator() async => moderator;

  @override
  Future<List<ModerationReport>> pendingReports({int limit = 50}) async {
    if (!moderator) throw _notModerator;
    final pending =
        _reports.where((r) => r.status == ReportStatus.pending).toList();
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending.take(limit).toList();
  }

  @override
  Future<ModerationOutcome> setReviewHidden(
    String reviewId, {
    required bool hidden,
    required String reason,
  }) async {
    final valid = _check(reviewId, reason);
    final targets = _reports.where((r) => r.reviewId == reviewId).toList();
    if (targets.isEmpty) {
      throw const AppFailure(
        FailureKind.validation,
        'Avaliação não encontrada.',
      );
    }
    if (targets.first.reviewHidden == hidden) {
      return ModerationOutcome.unchanged;
    }
    for (var i = 0; i < _reports.length; i++) {
      final report = _reports[i];
      if (report.reviewId != reviewId) continue;
      _reports[i] = report.copyWith(
        reviewHidden: hidden,
        status: hidden && report.status == ReportStatus.pending
            ? ReportStatus.actioned
            : null,
      );
    }
    log.add((
      action: hidden ? 'hide_review' : 'restore_review',
      targetId: reviewId,
      reason: valid,
    ));
    return ModerationOutcome.applied;
  }

  @override
  Future<ModerationOutcome> dismissReport(
    String reportId,
    String reason,
  ) async {
    final valid = _check(reportId, reason);
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index < 0) {
      throw const AppFailure(
        FailureKind.validation,
        'Denúncia não encontrada.',
      );
    }
    if (_reports[index].status != ReportStatus.pending) {
      return ModerationOutcome.unchanged;
    }
    _reports[index] = _reports[index].copyWith(status: ReportStatus.dismissed);
    log.add((action: 'dismiss_report', targetId: reportId, reason: valid));
    return ModerationOutcome.applied;
  }

  String _check(String id, String reason) {
    if (!moderator) {
      throw const AppFailure(
        FailureKind.unauthorized,
        'Você não tem permissão para esta operação.',
      );
    }
    _requireId(id);
    return validateModerationReason(reason);
  }
}
