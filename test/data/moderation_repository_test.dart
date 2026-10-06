import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/moderation_repository.dart';

const visibleReview = {
  'barcode': '7891000100103',
  'rating': 1,
  'comment': 'Texto denunciado',
  'visibility': 'visible',
  'profiles': {'nickname': 'Ana'},
};

Map<String, dynamic> row({String status = 'pending', Object? review}) => {
  'id': 'r1',
  'review_id': 'rev1',
  'reason': 'ofensa',
  'status': status,
  'created_at': '2026-10-05T12:00:00Z',
  'reviews': review ?? visibleReview,
};

ModerationReport report(String id, String reviewId, {int minute = 0}) =>
    ModerationReport(
      id: id,
      reviewId: reviewId,
      reason: 'spam',
      status: ReportStatus.pending,
      createdAt: DateTime.utc(2026, 10, 5, 12, minute),
      barcode: '7891000100103',
      rating: 2,
      comment: 'Comentário',
      authorNickname: 'Ana',
      reviewHidden: false,
    );

Matcher failure(FailureKind kind) =>
    throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', kind));

void main() {
  group('validateModerationReason', () {
    test('remove espaços e aceita 3 a 500 caracteres', () {
      expect(validateModerationReason('  Ofensa  '), 'Ofensa');
      expect(validateModerationReason('a' * 500), hasLength(500));
    });

    test('rejeita motivo vazio, curto ou longo', () {
      for (final value in ['', '   ', 'ab', 'a' * 501]) {
        expect(
          () => validateModerationReason(value),
          failure(FailureKind.validation),
        );
      }
    });
  });

  group('interpretModerationResult', () {
    test('ok e unchanged', () {
      expect(
        interpretModerationResult('ok', notFoundMessage: 'x'),
        ModerationOutcome.applied,
      );
      expect(
        interpretModerationResult('unchanged', notFoundMessage: 'x'),
        ModerationOutcome.unchanged,
      );
    });

    test('not_found usa a mensagem informada', () {
      expect(
        () => interpretModerationResult(
          'not_found',
          notFoundMessage: 'Avaliação não encontrada.',
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            'Avaliação não encontrada.',
          ),
        ),
      );
    });

    test('valor desconhecido é resposta inválida', () {
      expect(
        () => interpretModerationResult(null, notFoundMessage: 'x'),
        failure(FailureKind.invalidResponse),
      );
    });
  });

  group('moderationReportFromRow', () {
    test('lê denúncia com a avaliação e o autor', () {
      final item = moderationReportFromRow(row());
      expect(item.id, 'r1');
      expect(item.reviewId, 'rev1');
      expect(item.status, ReportStatus.pending);
      expect(item.barcode, '7891000100103');
      expect(item.rating, 1);
      expect(item.comment, 'Texto denunciado');
      expect(item.authorNickname, 'Ana');
      expect(item.reviewHidden, isFalse);
      expect(item.createdAt, DateTime.utc(2026, 10, 5, 12));
    });

    test('avaliação oculta, sem apelido e sem comentário', () {
      const hidden = {
        'barcode': '7891000100103',
        'rating': 3,
        'comment': null,
        'visibility': 'hidden',
        'profiles': null,
      };
      final item = moderationReportFromRow(
        row(status: 'actioned', review: hidden),
      );
      expect(item.status, ReportStatus.actioned);
      expect(item.reviewHidden, isTrue);
      expect(item.authorNickname, 'Colega');
      expect(item.comment, '');
    });

    test('status desconhecido ou sem avaliação é inválido', () {
      expect(
        () => moderationReportFromRow(row(status: 'reviewed')),
        failure(FailureKind.invalidResponse),
      );
      final missing = row()..['reviews'] = null;
      expect(
        () => moderationReportFromRow(missing),
        failure(FailureKind.invalidResponse),
      );
    });
  });

  group('InMemoryModeration', () {
    test('usuário comum não lê a fila nem decide', () async {
      final repo = InMemoryModeration(
        moderator: false,
        reports: [report('a', 'rev1')],
      );
      expect(await repo.isModerator(), isFalse);
      await expectLater(
        repo.pendingReports(),
        failure(FailureKind.unauthorized),
      );
      await expectLater(
        repo.setReviewHidden('rev1', hidden: true, reason: 'Ofensa'),
        failure(FailureKind.unauthorized),
      );
      await expectLater(
        repo.dismissReport('a', 'Sem problema'),
        failure(FailureKind.unauthorized),
      );
      expect(repo.log, isEmpty);
    });

    test('fila mostra pendentes da mais antiga para a mais nova', () async {
      final repo = InMemoryModeration(
        moderator: true,
        reports: [report('b', 'rev2', minute: 5), report('a', 'rev1')],
      );
      final queue = await repo.pendingReports();
      expect(queue.map((r) => r.id), ['a', 'b']);
    });

    test('ocultar resolve as denúncias da avaliação e registra', () async {
      final repo = InMemoryModeration(
        moderator: true,
        reports: [
          report('a', 'rev1'),
          report('b', 'rev1', minute: 1),
          report('c', 'rev2', minute: 2),
        ],
      );
      expect(
        await repo.setReviewHidden('rev1', hidden: true, reason: ' Ofensa '),
        ModerationOutcome.applied,
      );
      expect(
        await repo.setReviewHidden('rev1', hidden: true, reason: 'Ofensa'),
        ModerationOutcome.unchanged,
      );
      final queue = await repo.pendingReports();
      expect(queue.map((r) => r.id), ['c']);
      expect(repo.log.single.action, 'hide_review');
      expect(repo.log.single.reason, 'Ofensa');
    });

    test('restaurar é reversível e também fica na trilha', () async {
      final repo = InMemoryModeration(
        moderator: true,
        reports: [report('a', 'rev1')],
      );
      await repo.setReviewHidden('rev1', hidden: true, reason: 'Ofensa');
      expect(
        await repo.setReviewHidden('rev1', hidden: false, reason: 'Revisado'),
        ModerationOutcome.applied,
      );
      expect(repo.log.map((e) => e.action), ['hide_review', 'restore_review']);
    });

    test('arquivar não oculta e é idempotente', () async {
      final repo = InMemoryModeration(
        moderator: true,
        reports: [report('a', 'rev1')],
      );
      expect(
        await repo.dismissReport('a', 'Não é ofensa'),
        ModerationOutcome.applied,
      );
      expect(
        await repo.dismissReport('a', 'Não é ofensa'),
        ModerationOutcome.unchanged,
      );
      expect(await repo.pendingReports(), isEmpty);
      expect(repo.log.single.action, 'dismiss_report');
    });

    test('motivo inválido e alvo inexistente', () async {
      final repo = InMemoryModeration(
        moderator: true,
        reports: [report('a', 'rev1')],
      );
      await expectLater(
        repo.setReviewHidden('rev1', hidden: true, reason: ''),
        failure(FailureKind.validation),
      );
      await expectLater(
        repo.setReviewHidden('nao-existe', hidden: true, reason: 'Ofensa'),
        failure(FailureKind.validation),
      );
      await expectLater(
        repo.dismissReport('nao-existe', 'Motivo'),
        failure(FailureKind.validation),
      );
      expect(repo.log, isEmpty);
    });
  });
}
