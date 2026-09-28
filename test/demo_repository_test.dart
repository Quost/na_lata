import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';

void main() {
  test('catálogo simulado combina texto, marca e categoria', () async {
    final products = DemoProducts();
    final found = await products.search(
      const ProductQuery(text: 'leite', brand: 'Campo Bom', category: 'Leite'),
    );
    expect(found.map((p) => p.barcode), ['demo-leite-2']);
    expect(await products.byBarcode('inexistente'), isNull);
  });
  test(
    'dados fictícios mantêm avaliação de outro usuário fora de mine',
    () async {
      final reviews = DemoReviews();
      expect(
        (await reviews.mine()).every((r) => r.userId == 'demo-user'),
        isTrue,
      );
      expect(
        (await reviews.forProduct('demo-leite-1')).single.userId,
        'demo-peer',
      );
    },
  );
}
