import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/cache/cached_product_repository.dart';
import 'package:na_lata/data/clients/app_failure.dart';

class _FakeRepo implements ProductRepository {
  bool failWithNetwork = false;
  bool failWithUnknown = false;
  Product? toReturn;

  @override
  Future<Product?> byBarcode(String barcode) async {
    if (failWithNetwork) throw const AppFailure(FailureKind.network, 'offline');
    if (failWithUnknown) throw Exception('unknown');
    return toReturn;
  }

  @override
  Future<List<Product>> search(ProductQuery query) async => [];
  @override
  Future<void> importProduct(Product product) async {}
}

void main() {
  late _FakeRepo fakeRepo;
  late CachedProductRepository cacheRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    fakeRepo = _FakeRepo();
    cacheRepo = CachedProductRepository(fakeRepo, prefs);
  }

  group('CachedProductRepository', () {
    test('online: salva ficha buscada', () async {
      await initPrefs();
      fakeRepo.toReturn = const Product(barcode: '123', name: 'Teste');

      final prod = await cacheRepo.byBarcode('123');
      expect(prod?.name, 'Teste');

      // Fica offline e a ficha deve estar lá.
      fakeRepo.failWithNetwork = true;
      fakeRepo.toReturn = null;

      final cached = await cacheRepo.byBarcode('123');
      expect(cached?.name, 'Teste');
      expect(cached?.cachedAt, isNotNull);
    });

    test('offline: se não tem no cache, repassa erro original', () async {
      await initPrefs();
      fakeRepo.failWithNetwork = true;

      await expectLater(
        () => cacheRepo.byBarcode('999'),
        throwsA(isA<AppFailure>()),
      );
    });

    test('erros não-rede: repassa erro original ignorando cache', () async {
      await initPrefs();
      fakeRepo.toReturn = const Product(barcode: '123', name: 'T');
      await cacheRepo.byBarcode('123'); // Salva

      fakeRepo.failWithUnknown = true;
      await expectLater(
        () => cacheRepo.byBarcode('123'),
        throwsA(isA<Exception>()),
      );
    });

    test('parsing seguro: descarta schema inválido sem quebrar', () async {
      await initPrefs();
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('product_cache_bad', 'not a json');
      prefs.setStringList('cached_product_keys', ['product_cache_bad']);

      fakeRepo.failWithNetwork = true;

      // O repositório vai engolir a falha de parsing e repassar o offline.
      await expectLater(
        () => cacheRepo.byBarcode('bad'),
        throwsA(isA<AppFailure>()),
      );
    });

    test('lru limite de 50: remove mais antigo', () async {
      await initPrefs();
      // Gerar 51 fichas
      for (var i = 1; i <= 51; i++) {
        fakeRepo.toReturn = Product(barcode: '$i', name: 'Produto $i');
        await cacheRepo.byBarcode('$i');
      }

      fakeRepo.failWithNetwork = true;

      // O produto 1 (mais antigo) deve ter caído fora
      await expectLater(
        () => cacheRepo.byBarcode('1'),
        throwsA(isA<AppFailure>()), // Repassa erro porque não achou cache
      );

      // O produto 2 ainda está lá
      final p2 = await cacheRepo.byBarcode('2');
      expect(p2?.name, 'Produto 2');

      // O produto 51 também
      final p51 = await cacheRepo.byBarcode('51');
      expect(p51?.name, 'Produto 51');
    });
  });
}
