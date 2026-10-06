import '../../core/catalog_query.dart';
import '../../core/models.dart';
import '../../design_system/na_lata_ui.dart';

/// Filtros que o resumo sabe mostrar e remover.
///
/// A ordem dos valores é a ordem em que os chips aparecem.
enum CatalogFilterKind {
  text,
  barcode,
  brand,
  category,
  place,
  minRating,
  observedWithin;

  /// Lê o `id` devolvido por [NaFilterSummary.onRemove].
  static CatalogFilterKind fromId(String id) => values.byName(id);
}

NaFilterItem _item(CatalogFilterKind kind, String dimension, String value) =>
    NaFilterItem(id: kind.name, dimension: dimension, value: value);

/// Código IBGE mostrado enquanto não há nome de município (GEO01).
String _defaultCityName(String cityId) => 'IBGE $cityId';

/// Filtros ativos de [query], na ordem de [CatalogFilterKind].
///
/// Cidade e UF descrevem o mesmo local de observação e viram um único chip.
/// [cityName] permite trocar o código IBGE pelo nome do município.
/// A marca aparece como a chave normalizada que o [CatalogQuery] guarda.
List<NaFilterItem> catalogFilterItems(
  CatalogQuery query, {
  String Function(String cityId)? cityName,
}) {
  final cityId = query.cityId;
  final uf = query.uf;
  final days = query.observedWithinDays;
  return [
    if (query.text case final text?)
      _item(CatalogFilterKind.text, 'Nome', '“$text”'),
    if (query.barcode case final barcode?)
      _item(CatalogFilterKind.barcode, 'Código', barcode),
    if (query.brandKey case final brand?)
      _item(CatalogFilterKind.brand, 'Marca', brand),
    if (query.category case final category?)
      _item(CatalogFilterKind.category, 'Categoria', category),
    if (cityId != null || uf != null)
      _item(
        CatalogFilterKind.place,
        'Local',
        [
          if (cityId != null) (cityName ?? _defaultCityName)(cityId),
          ?uf,
        ].join('/'),
      ),
    if (query.minRating case final rating?)
      _item(CatalogFilterKind.minRating, 'Nota mínima', '$rating ou mais'),
    if (days != null)
      _item(
        CatalogFilterKind.observedWithin,
        'Período',
        days == 1 ? 'último dia' : 'últimos $days dias',
      ),
  ];
}

/// Filtros ativos de [query], a consulta que a tela de catálogo usa hoje.
///
/// Mostra a marca como o usuário a escolheu, sem normalizar.
List<NaFilterItem> productFilterItems(ProductQuery query) {
  final text = query.text.trim();
  return [
    if (text.isNotEmpty) _item(CatalogFilterKind.text, 'Nome', '“$text”'),
    if (query.brand case final brand?)
      _item(CatalogFilterKind.brand, 'Marca', brand),
    if (query.category case final category?)
      _item(CatalogFilterKind.category, 'Categoria', category),
  ];
}

/// Remove só o filtro [kind] de [query]; os outros e a ordenação ficam.
CatalogQuery removeCatalogFilter(CatalogQuery query, CatalogFilterKind kind) =>
    CatalogQuery(
      sort: query.sort,
      text: kind == CatalogFilterKind.text ? null : query.text,
      barcode: kind == CatalogFilterKind.barcode ? null : query.barcode,
      brandKey: kind == CatalogFilterKind.brand ? null : query.brandKey,
      category: kind == CatalogFilterKind.category ? null : query.category,
      cityId: kind == CatalogFilterKind.place ? null : query.cityId,
      uf: kind == CatalogFilterKind.place ? null : query.uf,
      minRating: kind == CatalogFilterKind.minRating ? null : query.minRating,
      observedWithinDays: kind == CatalogFilterKind.observedWithin
          ? null
          : query.observedWithinDays,
    );

/// Volta à consulta padrão, mantendo a ordenação (que não é um filtro).
CatalogQuery clearCatalogFilters(CatalogQuery query) =>
    CatalogQuery(sort: query.sort);

/// Versão de [removeCatalogFilter] para [ProductQuery]. Filtros que essa
/// consulta não tem deixam a consulta como está.
ProductQuery removeProductFilter(ProductQuery query, CatalogFilterKind kind) =>
    ProductQuery(
      text: kind == CatalogFilterKind.text ? '' : query.text,
      brand: kind == CatalogFilterKind.brand ? null : query.brand,
      category: kind == CatalogFilterKind.category ? null : query.category,
    );

/// Combinação ativa em texto corrido, para explicar um resultado vazio.
String describeFilters(List<NaFilterItem> items) =>
    items.map((item) => item.label).join(' • ');
