import 'clients/app_failure.dart';
import 'clients/backend_client.dart';
import '../core/contracts.dart';
import '../core/models.dart';
import '../features/report/report_logic.dart';
import '../features/sightings/sighting_logic.dart';

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
      // Não repete a gravação; a unicidade (review_id, user_id) barra duplicata.
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
  Future<List<Sighting>> sightings(String barcode) async {
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db
            .from('sightings')
            .select('barcode, store, city')
            .eq('barcode', barcode.trim())
            .order('created_at', ascending: false),
      ),
    );
    return rows
        .map(
          (row) => Sighting(
            barcode: row['barcode'] as String,
            store: row['store'] as String? ?? '',
            city: row['city'] as String? ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<void> addSighting(Sighting sighting) async {
    final valid = validateSighting(sighting);
    final userId = client.requireUserId;
    await client.request<void>(
      (db) async => db.from('sightings').insert({
        'barcode': valid.barcode,
        'store': valid.store,
        'city': valid.city,
        'user_id': userId,
      }),
    );
  }

  @override
  Future<void> setNickname(String nickname) async {
    final value = nickname.trim();
    if (value.isEmpty) {
      throw const AppFailure(FailureKind.validation, 'Digite um apelido.');
    }
    final userId = client.requireUserId; // nunca aceitar user_id da UI
    final rows = await client.request(
      (db) => db
          .from('profiles')
          .update({'nickname': value})
          .eq('id', userId)
          // Só o id: profiles tem leitura por coluna (PER01).
          .select('id'),
    );
    // UPDATE que afeta 0 linhas não lança erro: conferir o retorno.
    if ((rows as List).isEmpty) {
      throw const AppFailure(
        FailureKind.unauthorized,
        'Não foi possível atualizar seu apelido. Reinicie o aplicativo.',
      );
    }
  }
}
