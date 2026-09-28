import 'clients/backend_client.dart';
import '../core/contracts.dart';
import '../core/models.dart';

class SupabaseReviews implements ReviewRepository {
  SupabaseReviews(this.client);
  final BackendClient client;
  @override
  Future<List<Review>> forProduct(String barcode) async =>
      throw const FeaturePending('T08 — consultar avaliações');
  @override
  Future<List<Review>> mine() async =>
      throw const FeaturePending('T08 — minhas avaliações');
  @override
  Future<void> save(ReviewDraft draft) async =>
      throw const FeaturePending('T08 — salvar avaliação');
  @override
  Future<void> delete(String reviewId) async =>
      throw const FeaturePending('T17 — excluir avaliação');
}
