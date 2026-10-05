import '../core/contracts.dart';
import '../core/models.dart';
import 'clients/app_failure.dart';
import 'clients/backend_client.dart';

const maxBrandPageSize = 100;

const _accented = 'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇçÑñ';
const _plain = 'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn';
final _spaces = RegExp(r'\s+');

/// Mesma regra de `public.brand_search_key`: sem bordas, espaços únicos,
/// sem acentos e minúsculas. Usada só para pesquisar, nunca como identidade.
String brandSearchKey(String value) {
  final buffer = StringBuffer();
  for (final char in value.trim().replaceAll(_spaces, ' ').split('')) {
    final i = _accented.indexOf(char);
    buffer.write(i < 0 ? char : _plain[i]);
  }
  return buffer.toString().toLowerCase();
}

void checkBrandPageLimit(int limit) {
  if (limit < 1 || limit > maxBrandPageSize) {
    throw const AppFailure(
      FailureKind.validation,
      'Tamanho de página deve estar entre 1 e $maxBrandPageSize.',
    );
  }
}

/// [brands] traz até `limit + 1` itens; o excedente só indica a próxima página.
BrandPage brandPageOf(List<Brand> brands, int limit) => BrandPage(
  items: brands.take(limit).toList(),
  nextAfter: brands.length > limit ? brands[limit - 1].key : null,
);

class SupabaseBrands implements BrandRepository {
  SupabaseBrands(this.client);
  final BackendClient client;

  @override
  Future<BrandPage> search(String text, {String? after, int limit = 20}) async {
    checkBrandPageLimit(limit);
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db.rpc(
              'search_brands',
              params: {
                'p_query': text.trim(),
                'p_after': after,
                'p_limit': limit + 1,
              },
            )
            as List,
      ),
    );
    try {
      return brandPageOf([
        for (final row in rows)
          Brand(
            key: row['brand'] as String,
            productCount: (row['product_count'] as num).toInt(),
          ),
      ], limit);
    } on TypeError {
      throw const AppFailure(
        FailureKind.invalidResponse,
        'Resposta inesperada ao carregar marcas.',
      );
    }
  }
}
