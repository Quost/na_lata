import '../features/profile/profile_models.dart';
import 'clients/app_failure.dart';
import 'clients/backend_client.dart';

/// PER01 — perfil público. Convive com `CommunityRepository.setNickname` (T23).
abstract interface class ProfileRepository {
  /// Perfil público de qualquer usuário; null quando não existe.
  Future<PublicProfile?> byId(String userId);

  /// Perfil do usuário da sessão.
  Future<PublicProfile> mine();

  /// Atualiza apelido e bio do próprio perfil. Bio vazia apaga a bio.
  Future<PublicProfile> updateMine(ProfileDraft draft);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this.client);
  final BackendClient client;

  @override
  Future<PublicProfile?> byId(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return null;
    final row = await client.request(
      (db) => db
          .from('profiles')
          .select(publicProfileColumns)
          .eq('id', id)
          .maybeSingle(),
    );
    return row == null ? null : publicProfileFromRow(row);
  }

  @override
  Future<PublicProfile> mine() async {
    final profile = await byId(client.requireUserId);
    if (profile == null) {
      throw const AppFailure(FailureKind.unauthorized, profileNotFoundMessage);
    }
    return profile;
  }

  @override
  Future<PublicProfile> updateMine(ProfileDraft draft) async {
    final valid = validateProfileDraft(draft);
    final userId = client.requireUserId; // nunca aceitar id da UI
    final rows = await client.request(
      (db) => db
          .from('profiles')
          .update(profileToRow(valid))
          .eq('id', userId)
          .select(publicProfileColumns),
    );
    // UPDATE que afeta 0 linhas não lança erro: conferir o retorno.
    if (rows.isEmpty) {
      throw const AppFailure(FailureKind.unauthorized, profileNotFoundMessage);
    }
    return publicProfileFromRow(rows.first);
  }
}
