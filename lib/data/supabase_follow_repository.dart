import 'clients/app_failure.dart';
import 'clients/backend_client.dart';
import 'follow_repository.dart';

class SupabaseFollowRepository implements FollowRepository {
  const SupabaseFollowRepository(this._client);
  final BackendClient _client;

  @override
  Future<void> follow(String followedId) async {
    final userId = _client.requireUserId;
    if (userId == followedId) {
      throw const AppFailure(
        FailureKind.validation,
        'Não é possível seguir a si mesmo.',
      );
    }

    await _client.request(
      (db) => db.from('user_follows').upsert({
        'follower_id': userId,
        'followed_id': followedId,
      }),
    );
  }

  @override
  Future<void> unfollow(String followedId) async {
    final userId = _client.requireUserId;
    await _client.request(
      (db) => db
          .from('user_follows')
          .delete()
          .eq('follower_id', userId)
          .eq('followed_id', followedId),
    );
  }

  @override
  Future<List<String>> following() async {
    final userId = _client.requireUserId;
    final rows = await _client.request(
      (db) => db
          .from('user_follows')
          .select('followed_id')
          .eq('follower_id', userId),
    );
    return rows.map<String>((row) => row['followed_id'] as String).toList();
  }
}
