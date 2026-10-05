import 'clients/backend_client.dart';
import '../core/contracts.dart';
import '../core/models.dart';

class SupabaseProducts implements ProductRepository {
  SupabaseProducts(this.client);
  final BackendClient client;
  @override
  Future<List<Product>> search(ProductQuery query) async {
    final rows = await client.request<List<Map<String, dynamic>>>((db) async {
      var request = db.from('products').select();
      if (query.text.trim().isNotEmpty) {
        request = request.ilike('name', '%${query.text.trim()}%');
      }
      if (query.brand != null) {
        request = request.eq('brand_key', query.brand!);
      }
      if (query.category != null) {
        request = request.eq('category', query.category!);
      }
      return List<Map<String, dynamic>>.from(await request.order('name'));
    });
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Product?> byBarcode(String barcode) async {
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db.from('products').select().eq('barcode', barcode).limit(1),
      ),
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> importProduct(Product product) async {
    if (product.isDemo) return;
    final size = product.packageSize;
    await client.request<void>(
      (db) async => db
          .from('products')
          .upsert(
            {
              'barcode': product.barcode,
              'name': product.name.trim(),
              'brand_key': product.brand?.trim(),
              'category': product.category?.trim(),
              'image_url': product.imageUrl,
              // Só envia quando conhecido: tamanho ausente não grava nada.
              if (size != null) ...{
                'package_quantity': size.quantity,
                'package_unit': size.unit.symbol,
                'package_source': size.source.code,
              },
            },
            onConflict: 'barcode',
            ignoreDuplicates: true,
          ),
    );
  }

  Product _fromRow(Map<String, dynamic> row) => Product(
    barcode: row['barcode'] as String,
    name: row['name'] as String,
    brand: row['brand_key'] as String?,
    category: row['category'] as String?,
    imageUrl: row['image_url'] as String?,
    packageSize: PackageSize.fromColumns(
      quantity: row['package_quantity'],
      unit: row['package_unit'],
      source: row['package_source'],
    ),
  );
}
