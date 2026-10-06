import '../../data/clients/app_failure.dart';
import '../nickname/nickname_feature.dart';

const profileBioMaxLength = 160;
const profileNotFoundMessage =
    'Não foi possível carregar seu perfil. Reinicie o aplicativo.';

/// O que qualquer usuário autenticado pode ler de outra pessoa.
///
/// Só campos públicos entram aqui. Email, token, claims e preferências
/// privadas não pertencem a este modelo nem a [publicProfileColumns].
class PublicProfile {
  const PublicProfile({required this.id, required this.nickname, this.bio});
  final String id, nickname;
  final String? bio;
}

/// Campos que a pessoa pode editar no próprio perfil. O id vem da sessão.
class ProfileDraft {
  const ProfileDraft({required this.nickname, this.bio});
  final String nickname;
  final String? bio;
}

/// Mesmas regras do banco: apelido 2–40 após trim, bio opcional até 160.
/// Conta caracteres (runes), como `char_length` do Postgres.
ProfileDraft validateProfileDraft(ProfileDraft draft) {
  final nickname = validateNickname(draft.nickname);
  if (!nickname.isValid) {
    throw AppFailure(
      FailureKind.validation,
      nicknameErrorMessage(nickname.error!),
    );
  }
  final bio = draft.bio?.trim() ?? '';
  if (bio.runes.length > profileBioMaxLength) {
    throw const AppFailure(
      FailureKind.validation,
      'A bio pode ter até $profileBioMaxLength caracteres.',
    );
  }
  return ProfileDraft(nickname: nickname.value!, bio: bio.isEmpty ? null : bio);
}

/// Colunas pedidas ao PostgREST. Lista explícita: coluna nova em `profiles`
/// não vaza para o app sem passar por aqui e pelo grant do banco.
const publicProfileColumns = 'id, nickname, bio';

PublicProfile publicProfileFromRow(Map<String, dynamic> row) {
  final bio = (row['bio'] as String?)?.trim() ?? '';
  return PublicProfile(
    id: row['id'] as String,
    nickname: row['nickname'] as String,
    bio: bio.isEmpty ? null : bio,
  );
}

Map<String, dynamic> profileToRow(ProfileDraft draft) => {
  'nickname': draft.nickname,
  'bio': draft.bio,
};
