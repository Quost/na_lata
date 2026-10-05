import 'dart:convert';

import '../data/clients/app_failure.dart';

/// Ordenações aceitas pelo catálogo. O nome serializado é estável.
enum CatalogSort {
  name('name'),
  rating('rating'),
  recent('recent');

  const CatalogSort(this.wire);
  final String wire;

  static CatalogSort parse(Object? value) {
    for (final sort in values) {
      if (sort.wire == value) return sort;
    }
    throw _invalid('Ordenação inválida.');
  }
}

/// Siglas aceitas em [CatalogQuery.uf].
const brazilianUfs = {
  'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', //
  'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', //
  'SE', 'SP', 'TO',
};

const maxObservationWindowDays = 365;

final _barcode = RegExp(r'^\d{8,14}$');
final _cityId = RegExp(r'^\d{7}$');
final _spaces = RegExp(r'\s+');

/// Chave de marca comparável: sem bordas, minúsculas e espaços únicos.
String catalogBrandKey(String brand) =>
    brand.trim().toLowerCase().replaceAll(_spaces, ' ');

AppFailure _invalid(String message) =>
    AppFailure(FailureKind.validation, message);

/// Filtros da jornada de catálogo. Campo nulo significa "Todos" e os
/// filtros presentes são combinados com AND.
///
/// [cityId] (código IBGE) e [uf] descrevem o local da observação do produto,
/// nunca a cidade de quem avaliou. [observedWithinDays] limita essas
/// observações aos últimos N dias.
class CatalogQuery {
  const CatalogQuery._({
    required this.sort,
    this.text,
    this.barcode,
    this.brandKey,
    this.category,
    this.cityId,
    this.uf,
    this.minRating,
    this.observedWithinDays,
  });

  /// Normaliza e valida; lança [AppFailure] de validação se algo for inválido.
  /// Texto vazio equivale a filtro ausente.
  factory CatalogQuery({
    CatalogSort sort = CatalogSort.name,
    String? text,
    String? barcode,
    String? brandKey,
    String? category,
    String? cityId,
    String? uf,
    int? minRating,
    int? observedWithinDays,
  }) {
    final code = _blankToNull(barcode);
    if (code != null && !_barcode.hasMatch(code)) {
      throw _invalid('Código de barras deve ter de 8 a 14 dígitos.');
    }
    final city = _blankToNull(cityId);
    if (city != null && !_cityId.hasMatch(city)) {
      throw _invalid('Cidade deve ser um código IBGE de 7 dígitos.');
    }
    final state = _blankToNull(uf)?.toUpperCase();
    if (state != null && !brazilianUfs.contains(state)) {
      throw _invalid('UF inválida.');
    }
    if (minRating != null && (minRating < 1 || minRating > 5)) {
      throw _invalid('Nota mínima deve estar entre 1 e 5.');
    }
    if (observedWithinDays != null &&
        (observedWithinDays < 1 ||
            observedWithinDays > maxObservationWindowDays)) {
      throw _invalid(
        'Janela de observações deve ter de 1 a $maxObservationWindowDays dias.',
      );
    }
    final brand = _blankToNull(brandKey);
    return CatalogQuery._(
      sort: sort,
      text: _blankToNull(text),
      barcode: code,
      brandKey: brand == null ? null : catalogBrandKey(brand),
      category: _blankToNull(category),
      cityId: city,
      uf: state,
      minRating: minRating,
      observedWithinDays: observedWithinDays,
    );
  }

  /// Versão atual do formato de [toJson].
  static const version = 1;

  static const _keys = {
    'v',
    'sort',
    'text',
    'barcode',
    'brandKey',
    'category',
    'cityId',
    'uf',
    'minRating',
    'observedWithinDays',
  };

  /// Lê o formato versionado; versão, chave ou tipo desconhecido é rejeitado.
  factory CatalogQuery.fromJson(Map<String, Object?> json) {
    if (json['v'] != version) {
      throw _invalid('Versão de filtro não suportada.');
    }
    if (json.keys.any((k) => !_keys.contains(k))) {
      throw _invalid('Filtro desconhecido.');
    }
    return CatalogQuery(
      sort: json.containsKey('sort')
          ? CatalogSort.parse(json['sort'])
          : CatalogSort.name,
      text: _read<String>(json, 'text'),
      barcode: _read<String>(json, 'barcode'),
      brandKey: _read<String>(json, 'brandKey'),
      category: _read<String>(json, 'category'),
      cityId: _read<String>(json, 'cityId'),
      uf: _read<String>(json, 'uf'),
      minRating: _read<int>(json, 'minRating'),
      observedWithinDays: _read<int>(json, 'observedWithinDays'),
    );
  }

  final CatalogSort sort;
  final String? text, barcode, brandKey, category, cityId, uf;
  final int? minRating, observedWithinDays;

  /// Exige filtro por local ou data de observação.
  bool get filtersObservations =>
      cityId != null || uf != null || observedWithinDays != null;

  /// Formato versionado, com chaves em ordem fixa e sem filtros ausentes.
  Map<String, Object?> toJson() => {
    'v': version,
    'sort': sort.wire,
    'text': ?text,
    'barcode': ?barcode,
    'brandKey': ?brandKey,
    'category': ?category,
    'cityId': ?cityId,
    'uf': ?uf,
    'minRating': ?minRating,
    'observedWithinDays': ?observedWithinDays,
  };

  String get _canonical => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is CatalogQuery && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

T? _read<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is T) return value as T?;
  throw _invalid('Filtro "$key" com tipo inválido.');
}

/// Posição opaca de paginação, válida só para a consulta que a gerou.
class CatalogCursor {
  const CatalogCursor(this.token);

  /// Uso dos repositórios: cria o cursor da próxima página de [query].
  factory CatalogCursor.after(CatalogQuery query, int offset) => CatalogCursor(
    base64Url.encode(
      utf8.encode(jsonEncode({'v': 1, 'q': query._canonical, 'o': offset})),
    ),
  );

  final String token;

  /// Uso dos repositórios: posição para [query], ou 0 se o cursor foi
  /// gerado com outros filtros/ordem (paginação reinicia).
  /// Token corrompido é rejeitado.
  int offsetFor(CatalogQuery query) {
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(base64Url.decode(token)));
    } on FormatException {
      throw _invalid('Cursor de paginação inválido.');
    }
    if (data is! Map ||
        data['v'] != 1 ||
        data['q'] is! String ||
        data['o'] is! int ||
        (data['o'] as int) < 0) {
      throw _invalid('Cursor de paginação inválido.');
    }
    return data['q'] == query._canonical ? data['o'] as int : 0;
  }

  @override
  bool operator ==(Object other) =>
      other is CatalogCursor && other.token == token;

  @override
  int get hashCode => token.hashCode;
}

/// Página de resultados; [next] nulo indica a última página.
class PageResult<T> {
  const PageResult({required this.items, this.next});
  final List<T> items;
  final CatalogCursor? next;
  bool get hasMore => next != null;
}

/// Produto visto em um local; base dos filtros de região e janela.
class CatalogObservation {
  const CatalogObservation({
    required this.barcode,
    required this.cityId,
    required this.uf,
    required this.observedAt,
  });
  final String barcode, cityId, uf;
  final DateTime observedAt;
}
