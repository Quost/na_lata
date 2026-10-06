import 'follow_repository.dart';

class DemoFollowRepository implements FollowRepository {
  DemoFollowRepository(this.userId);

  final String userId;
  final Set<String> _following = {};

  @override
  Future<void> follow(String followedId) async {
    if (followedId == userId) {
      throw StateError('Não é possível seguir a si mesmo.');
    }
    _following.add(followedId);
  }

  @override
  Future<void> unfollow(String followedId) async {
    _following.remove(followedId);
  }

  @override
  Future<List<String>> following() async {
    return _following.toList();
  }
}
