import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/contracts.dart';
import '../core/models.dart';

class SupabaseProducts implements ProductRepository {
  SupabaseProducts(this.client);
  final SupabaseClient client;
  @override
  Future<List<Product>> search(ProductQuery query) async =>
      throw const FeaturePending('T02 — catálogo Supabase');
  @override
  Future<Product?> byBarcode(String barcode) async =>
      throw const FeaturePending('T02 — catálogo Supabase');
  @override
  Future<void> importProduct(Product product) async =>
      throw const FeaturePending('T02 — importar produto');
}
