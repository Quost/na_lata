import 'clients/backend_client.dart';
import '../core/contracts.dart';
import '../core/models.dart';
import '../features/report/report_logic.dart';
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
  Future<void> report(String reviewId, String reason) async {
    final parsed = ReportReason.tryParse(reason);
    if (parsed == null || reviewId.trim().isEmpty) {
      throw const AppFailure(
        FailureKind.validation,
        'Escolha um motivo: ofensa, spam ou outro.',
      );
    }
    final userId = client.requireUserId;
    try {
      // Não repete a gravação; a unicidade (review_id, user_id) detecta duplicata.
      await client.request(
        (db) => db.from('reports').insert({
          'review_id': reviewId,
          'user_id': userId,
          'reason': parsed.value,
          'status': 'pending',
        }),
      );
    } on AppFailure catch (error) {
      if (error.kind == FailureKind.conflict) {
        throw const AppFailure(FailureKind.conflict, duplicateReportMessage);
      }
      rethrow;
    }
  }
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
