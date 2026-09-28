import 'clients/backend_client.dart';
import '../core/contracts.dart';
import '../core/models.dart';

class SupabaseCommunity implements CommunityRepository {
  SupabaseCommunity(this.client);
  final BackendClient client;
  @override
  Future<Set<String>> favorites() async {
    final userId = client.requireUserId;
    final rows = await client.request(
      (db) => db.from('favorites').select('barcode').eq('user_id', userId),
    );
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['barcode'] as String)
        .toSet();
  }

  @override
  Future<void> setFavorite(String barcode, bool value) async {
    final userId = client.requireUserId;
    if (value) {
      await client.request(
        (db) => db
            .from('favorites')
            .upsert(
              {'user_id': userId, 'barcode': barcode},
              onConflict: 'user_id,barcode',
              ignoreDuplicates: true,
            ),
      );
      return;
    }
    await client.request(
      (db) => db
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('barcode', barcode),
    );
  }

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
  Future<void> setNickname(String nickname) async =>
      throw const FeaturePending('T23 — apelido');
}
