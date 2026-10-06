abstract interface class FollowRepository {
  /// Segue um usuário. É idempotente.
  /// Não permite autoseguimento (lança exceção).
  Future<void> follow(String followedId);

  /// Deixa de seguir um usuário. É idempotente.
  Future<void> unfollow(String followedId);

  /// Retorna a lista de IDs de usuários que a sessão atual está seguindo.
  Future<List<String>> following();
}
