import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/catalog_query.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';

final _now = DateTime.utc(2026, 10, 5);

Matcher get _validation => throwsA(
  isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.validation),
);

Product _product(String barcode, String name, {String? brand, String? cat}) =>
    Product(barcode: barcode, name: name, brand: brand, category: cat);

Review _review(String barcode, int rating, String userId) => Review(
  id: '$barcode-$userId',
  barcode: barcode,
  userId: userId,
  nickname: userId,
  rating: rating,
  comment: '',
  createdAt: _now,
);

CatalogObservation _seen(String barcode, String cityId, String uf, int ago) =>
    CatalogObservation(
      barcode: barcode,
      cityId: cityId,
      uf: uf,
      observedAt: _now.subtract(Duration(days: ago)),
    );

const _joinville = '4209102', _curitiba = '4106902';

DemoCatalog _catalog() => DemoCatalog(
  now: () => _now,
  products: [
    _product(
      '07891000100103',
      'Leite integral',
      brand: 'Fazenda Aurora',
      cat: 'Leite',
    ),
    _product(
      '07891000200200',
      'Leite desnatado',
      brand: 'Campo  Bom',
      cat: 'Leite',
    ),
    _product(
      '07891000300307',
      'Chocolate 70%',
      brand: 'Fazenda Aurora',
      cat: 'Chocolate',
    ),
    _product(
      '07891000400404',
      'Leite em pó',
      brand: 'Fazenda Aurora',
      cat: 'Leite',
    ),
  ],
  reviews: [
    _review('07891000100103', 5, 'a'),
    _review('07891000100103', 4, 'b'),
    _review('07891000200200', 2, 'a'),
    _review('07891000300307', 5, 'a'),
    _review('07891000400404', 4, 'a'),
  ],
  observations: [
    _seen('07891000100103', _joinville, 'SC', 3),
    _seen('07891000200200', _joinville, 'SC', 1),
    _seen('07891000300307', _curitiba, 'PR', 2),
    _seen('07891000400404', _joinville, 'SC', 60),
    _seen('07891000400404', _curitiba, 'PR', 5),
  ],
);

void main() {
  group('CatalogQuery', () {
    test('filtros ausentes e vazios equivalem a Todos', () {
      final all = CatalogQuery();
      expect(all.toJson(), {'v': 1, 'sort': 'name'});
      expect(CatalogQuery(text: '  ', brandKey: '', uf: ' '), all);
      expect(all.filtersObservations, isFalse);
    });

    test('round-trip preserva todos os filtros e zeros do barcode', () {
      final query = CatalogQuery(
        sort: CatalogSort.recent,
        text: 'leite',
        barcode: '00012345',
        brandKey: '  Fazenda   AURORA ',
        category: 'Leite',
        cityId: _joinville,
        uf: 'sc',
        minRating: 4,
        observedWithinDays: 30,
      );
      final json = query.toJson();
      expect(json['barcode'], '00012345');
      expect(json['brandKey'], 'fazenda aurora');
      expect(json['uf'], 'SC');
      final back = CatalogQuery.fromJson(json);
      expect(back, query);
      expect(back.barcode, '00012345');
      expect(back.toJson(), json);
    });

    test('valores inválidos são rejeitados', () {
      expect(() => CatalogQuery(barcode: '123'), _validation);
      expect(() => CatalogQuery(barcode: '1234567a'), _validation);
      expect(() => CatalogQuery(cityId: 'Joinville'), _validation);
      expect(() => CatalogQuery(uf: 'XX'), _validation);
      expect(() => CatalogQuery(minRating: 0), _validation);
      expect(() => CatalogQuery(minRating: 6), _validation);
      expect(() => CatalogQuery(observedWithinDays: 0), _validation);
      expect(() => CatalogQuery(observedWithinDays: 366), _validation);
    });

    test('serialização rejeita versão, chave, tipo e ordem desconhecidos', () {
      expect(() => CatalogQuery.fromJson({'sort': 'name'}), _validation);
      expect(() => CatalogQuery.fromJson({'v': 2}), _validation);
      expect(() => CatalogQuery.fromJson({'v': 1, 'city': 'x'}), _validation);
      expect(
        () => CatalogQuery.fromJson({'v': 1, 'barcode': 12345678}),
        _validation,
      );
      expect(
        () => CatalogQuery.fromJson({'v': 1, 'sort': 'preco'}),
        _validation,
      );
      expect(CatalogQuery.fromJson({'v': 1}), CatalogQuery());
    });
  });

  group('DemoCatalog', () {
    Future<List<String>> barcodes(CatalogQuery query) async =>
        (await _catalog().page(query)).items.map((p) => p.barcode).toList();

    test('sem filtros devolve todos ordenados por nome', () async {
      expect(await barcodes(CatalogQuery()), [
        '07891000300307',
        '07891000200200',
        '07891000400404',
        '07891000100103',
      ]);
    });

    test('filtros combinam com AND', () async {
      expect(
        await barcodes(
          CatalogQuery(
            text: 'LEITE',
            brandKey: 'fazenda aurora',
            category: 'Leite',
            minRating: 4,
            uf: 'SC',
            observedWithinDays: 30,
          ),
        ),
        ['07891000100103'],
      );
      expect(
        await barcodes(CatalogQuery(brandKey: 'Campo Bom', minRating: 4)),
        isEmpty,
      );
      expect(await barcodes(CatalogQuery(barcode: '07891000200200')), [
        '07891000200200',
      ]);
    });

    test('região usa o local da observação dentro da janela', () async {
      // Avaliador "a" não tem cidade; só a observação conta.
      expect(await barcodes(CatalogQuery(cityId: _curitiba)), [
        '07891000300307',
        '07891000400404',
      ]);
      // Visto em Joinville há 60 dias: fora da janela de 30 dias.
      expect(
        await barcodes(
          CatalogQuery(cityId: _joinville, observedWithinDays: 30),
        ),
        ['07891000200200', '07891000100103'],
      );
    });

    test('ordena por nota e por observação mais recente', () async {
      expect(await barcodes(CatalogQuery(sort: CatalogSort.rating)), [
        '07891000300307',
        '07891000100103',
        '07891000400404',
        '07891000200200',
      ]);
      expect(await barcodes(CatalogQuery(sort: CatalogSort.recent)), [
        '07891000200200',
        '07891000300307',
        '07891000100103',
        '07891000400404',
      ]);
    });

    test('pagina com cursor opaco até o fim', () async {
      final catalog = _catalog();
      final query = CatalogQuery(text: 'leite');
      final first = await catalog.page(query, limit: 2);
      expect(first.items, hasLength(2));
      expect(first.hasMore, isTrue);
      expect(first.next!.token, isNot(contains('leite')));
      final second = await catalog.page(query, after: first.next, limit: 2);
      expect(second.items.map((p) => p.barcode), ['07891000100103']);
      expect(second.hasMore, isFalse);
    });

    test('mudar filtro ou ordem reinicia a paginação', () async {
      final catalog = _catalog();
      final first = await catalog.page(CatalogQuery(), limit: 2);

      final otherFilter = CatalogQuery(category: 'Leite');
      final restarted = await catalog.page(
        otherFilter,
        after: first.next,
        limit: 2,
      );
      expect(
        restarted.items.map((p) => p.barcode),
        (await catalog.page(otherFilter, limit: 2)).items.map((p) => p.barcode),
      );

      final otherSort = CatalogQuery(sort: CatalogSort.rating);
      final resorted = await catalog.page(otherSort, after: first.next);
      expect(resorted.items.first.barcode, '07891000300307');
      expect(resorted.items, hasLength(4));
    });

    test('cursor corrompido e limite inválido são rejeitados', () async {
      final catalog = _catalog();
      expect(
        () => catalog.page(CatalogQuery(), after: const CatalogCursor('@@')),
        _validation,
      );
      expect(() => catalog.page(CatalogQuery(), limit: 0), _validation);
    });

    test('estado vazio devolve página sem próximo cursor', () async {
      final page = await _catalog().page(CatalogQuery(text: 'inexistente'));
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });
}
