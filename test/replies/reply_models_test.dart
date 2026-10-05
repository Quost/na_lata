import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/features/replies/reply_models.dart';

Map<String, dynamic> row({Object? profiles = const {'nickname': 'Ana'}}) => {
  'id': 'r1',
  'review_id': 'v1',
  'author_id': 'u1',
  'body': 'Concordo!',
  'created_at': '2026-10-05T12:00:00+00:00',
  'updated_at': '2026-10-05T12:00:00+00:00',
  'profiles': profiles,
};

void main() {
  group('replyFromRow', () {
    test('mapeia campos e apelido', () {
      final reply = replyFromRow(row());
      expect(reply.id, 'r1');
      expect(reply.reviewId, 'v1');
      expect(reply.authorId, 'u1');
      expect(reply.authorNickname, 'Ana');
      expect(reply.body, 'Concordo!');
      expect(reply.edited, isFalse);
    });

    test('aceita apelido em lista ou ausente', () {
      expect(
        replyFromRow(
          row(
            profiles: [
              {'nickname': 'Bia'},
            ],
          ),
        ).authorNickname,
        'Bia',
      );
      expect(replyFromRow(row(profiles: null)).authorNickname, 'Colega');
    });

    test('marca como editada quando updated_at é posterior', () {
      final edited = row()..['updated_at'] = '2026-10-05T12:05:00+00:00';
      expect(replyFromRow(edited).edited, isTrue);
    });

    test('data inválida não vira valor padrão', () {
      final broken = row()..['created_at'] = 'ontem';
      expect(() => replyFromRow(broken), throwsFormatException);
    });
  });

  group('validateReplyBody', () {
    Matcher validation() =>
        isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.validation);

    test('rejeita vazio e só espaços', () {
      expect(() => validateReplyBody(''), throwsA(validation()));
      expect(() => validateReplyBody('  \n '), throwsA(validation()));
    });

    test('limite de 500 caracteres', () {
      expect(validateReplyBody('a' * 500), 'a' * 500);
      expect(() => validateReplyBody('a' * 501), throwsA(validation()));
    });

    test('conta caracteres, não bytes', () {
      expect(validateReplyBody('é' * 500), 'é' * 500);
    });

    test('preserva o texto original sem alterar espaços', () {
      expect(validateReplyBody('  oi  '), '  oi  ');
    });
  });
}
