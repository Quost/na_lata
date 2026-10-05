import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/features/profile/profile_models.dart';

Matcher failure(FailureKind kind) =>
    isA<AppFailure>().having((e) => e.kind, 'kind', kind);

void main() {
  group('validateProfileDraft', () {
    test('aplica trim no apelido e na bio', () {
      final valid = validateProfileDraft(
        const ProfileDraft(nickname: '  Ana  ', bio: '  Gosto de café  '),
      );
      expect(valid.nickname, 'Ana');
      expect(valid.bio, 'Gosto de café');
    });

    test('bio ausente, vazia ou só com espaços vira null', () {
      for (final bio in [null, '', '   \n ']) {
        final valid = validateProfileDraft(
          ProfileDraft(nickname: 'Ana', bio: bio),
        );
        expect(valid.bio, isNull);
      }
    });

    test('apelido aceita 2 e 40 caracteres e recusa 1 e 41', () {
      expect(
        validateProfileDraft(const ProfileDraft(nickname: 'ab')).nickname,
        'ab',
      );
      expect(
        validateProfileDraft(ProfileDraft(nickname: 'a' * 40)).nickname,
        hasLength(40),
      );
      for (final nickname in ['', '   ', ' a ', 'a' * 41]) {
        expect(
          () => validateProfileDraft(ProfileDraft(nickname: nickname)),
          throwsA(failure(FailureKind.validation)),
        );
      }
    });

    test('bio aceita 160 caracteres e recusa 161', () {
      expect(
        validateProfileDraft(
          ProfileDraft(nickname: 'Ana', bio: 'a' * profileBioMaxLength),
        ).bio,
        hasLength(profileBioMaxLength),
      );
      expect(
        () => validateProfileDraft(
          ProfileDraft(nickname: 'Ana', bio: 'a' * (profileBioMaxLength + 1)),
        ),
        throwsA(failure(FailureKind.validation)),
      );
    });

    test('espaços nas bordas não contam para o limite da bio', () {
      final valid = validateProfileDraft(
        ProfileDraft(nickname: 'Ana', bio: '  ${'a' * profileBioMaxLength}  '),
      );
      expect(valid.bio, hasLength(profileBioMaxLength));
    });

    test('emoji e acento contam como um caractere', () {
      // Cada emoji ocupa 2 unidades UTF-16; o limite é por caractere.
      final valid = validateProfileDraft(
        ProfileDraft(nickname: '😀é', bio: '😀' * profileBioMaxLength),
      );
      expect(valid.nickname, '😀é');
      expect(valid.bio!.runes, hasLength(profileBioMaxLength));
      expect(
        () => validateProfileDraft(const ProfileDraft(nickname: '😀')),
        throwsA(failure(FailureKind.validation)),
      );
    });
  });

  group('mapper', () {
    test('pede só colunas públicas, sem curinga', () {
      expect(publicProfileColumns, 'id, nickname, bio');
    });

    test('ignora campos privados que venham na linha', () {
      final profile = publicProfileFromRow({
        'id': 'u1',
        'nickname': 'Ana',
        'bio': 'Gosto de café',
        'email': 'ana@example.com',
        'role': 'moderator',
      });
      expect(profile.id, 'u1');
      expect(profile.nickname, 'Ana');
      expect(profile.bio, 'Gosto de café');
    });

    test('bio nula ou em branco no banco vira null', () {
      for (final bio in [null, '', '  ']) {
        final profile = publicProfileFromRow({
          'id': 'u1',
          'nickname': 'Ana',
          'bio': bio,
        });
        expect(profile.bio, isNull);
      }
    });

    test('escrita envia só apelido e bio', () {
      expect(profileToRow(const ProfileDraft(nickname: 'Ana')), {
        'nickname': 'Ana',
        'bio': null,
      });
    });
  });
}
