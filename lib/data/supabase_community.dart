import 'clients/backend_client.dart';
import '../core/contracts.dart';
import '../core/models.dart';

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
  Future<void> setNickname(String nickname) async =>
      throw const FeaturePending('T23 — apelido');
}
