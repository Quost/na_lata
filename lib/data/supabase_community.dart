import 'clients/backend_client.dart';
import '../core/contracts.dart';
import '../core/models.dart';
import 'clients/app_failure.dart';

class SupabaseCommunity implements CommunityRepository {
  SupabaseCommunity(this.client);
  final BackendClient client;
  @override
  Future<Set<String>> favorites() async =>
      throw const FeaturePending('T18 — favoritos');
  @override
  Future<void> setFavorite(String barcode, bool value) async =>
      throw const FeaturePending('T18 — favoritos');
  @override
  Future<void> report(String reviewId, String reason) async =>
      throw const FeaturePending('T19 — denúncia');
  @override
  Future<List<Sighting>> sightings(String barcode) async =>
      throw const FeaturePending('T22 — relatos');
  @override
  Future<void> addSighting(Sighting sighting) async =>
      throw const FeaturePending('T22 — relatos');
  @override
  Future<void> setNickname(String nickname) async {
    final userId = client.requireUserId; // nunca aceitar user_id da UI
    final value = nickname.trim();
    final rows = await client.request(
      (db) => db
          .from('profiles')
          .update({'nickname': value})
          .eq('id', userId) // ASSUMIDO: PK de profiles = id do auth
          .select(),
    );
    // UPDATE que afeta 0 linhas não lança erro: conferir o retorno.
    if ((rows as List).isEmpty) {
      throw const AppFailure(
        /* ASSUMIDO: kind permissão/validação */
        FailureKind.unauthorized,
        'Não foi possível atualizar seu apelido. Reinicie o aplicativo.',
      );
    }
  }
}
