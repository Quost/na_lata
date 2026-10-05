import '../features/profile/profile_models.dart';
import 'profile_repository.dart';

/// Armazenamento compartilhado entre usuários fictícios, para simular A/B.
class DemoProfileStore {
  final Map<String, PublicProfile> profiles = {};
}

/// Fake com as mesmas regras do banco: todos leem o perfil público e cada
/// usuário só altera o próprio, sempre pelo id da sessão.
class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository({this.userId = 'demo-user', DemoProfileStore? store})
    : store = store ?? DemoProfileStore() {
    // Equivalente ao trigger que cria o perfil junto com o usuário.
    this.store.profiles.putIfAbsent(
      userId,
      () => PublicProfile(id: userId, nickname: 'Colega'),
    );
  }

  final String userId;
  final DemoProfileStore store;

  @override
  Future<PublicProfile?> byId(String userId) async =>
      store.profiles[userId.trim()];

  @override
  Future<PublicProfile> mine() async => store.profiles[userId]!;

  @override
  Future<PublicProfile> updateMine(ProfileDraft draft) async {
    final valid = validateProfileDraft(draft);
    return store.profiles[userId] = PublicProfile(
      id: userId,
      nickname: valid.nickname,
      bio: valid.bio,
    );
  }
}
