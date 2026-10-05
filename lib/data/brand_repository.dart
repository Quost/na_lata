import '../core/contracts.dart';
import '../data/clients/app_failure.dart';
import 'clients/backend_client.dart';

class SupabaseBrandFollows implements BrandFollowRepository {
  SupabaseBrandFollows(this.client);

  final BackendClient client;

  @override
  Future<bool> isFollowing(String brandKey) async {
    final key = _normalizeBrandKey(brandKey);
    _validateBrandKey(key);
    final userId = client.requireUserId;
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db
            .from('brand_follows')
            .select('brand_key')
            .eq('user_id', userId)
            .eq('brand_key', key)
            .limit(1),
      ),
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<String>> followingBrands() async {
    final userId = client.requireUserId;
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db
            .from('brand_follows')
            .select('brand_key')
            .eq('user_id', userId)
            .order('brand_key'),
      ),
    );
    return rows.map((row) => row['brand_key'] as String).toList();
  }

  @override
  Future<void> setFollowing({
    required String brandKey,
    required bool isFollowing,
  }) async {
    final key = _normalizeBrandKey(brandKey);
    _validateBrandKey(key);
    final userId = client.requireUserId;
    await client.request<void>((db) async {
      if (isFollowing) {
        await db
            .from('brand_follows')
            .upsert(
              {'user_id': userId, 'brand_key': key},
              onConflict: 'user_id,brand_key',
              ignoreDuplicates: true,
            );
      } else {
        await db
            .from('brand_follows')
            .delete()
            .eq('user_id', userId)
            .eq('brand_key', key);
      }
    });
  }

  void _validateBrandKey(String key) {
    if (key.isEmpty || key.length > 120) {
      throw const AppFailure(
        FailureKind.validation,
        'A marca selecionada não é válida.',
      );
    }
  }

  String _normalizeBrandKey(String value) => value.trim().toLowerCase();
}
