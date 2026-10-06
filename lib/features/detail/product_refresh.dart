import '../../core/models.dart';
import '../../core/product_source.dart';
import '../../data/clients/app_failure.dart';
import '../../data/open_food_facts_repository.dart';

/// Intervalo mínimo entre duas atualizações do mesmo produto; o banco aplica
/// a mesma regra em `public.refresh_product`.
const productRefreshInterval = Duration(hours: 1);
const productNameMaxLength = 300;
const productGoneMessage = 'Este produto não está mais no catálogo.';

/// Campos de catálogo que a atualização pela fonte pode gravar. Avaliações,
/// favoritos, relatos e o próprio código de barras ficam de fora.
class CatalogUpdate {
  const CatalogUpdate({
    required this.barcode,
    required this.name,
    this.brand,
    this.category,
    this.imageUrl,
  });
  final String barcode, name;
  final String? brand, category, imageUrl;
}

/// Um campo que muda, com os valores já prontos para exibir.
class CatalogChange {
  const CatalogChange({
    required this.label,
    required this.before,
    required this.after,
  });
  final String label, before, after;
}

String? _blankToNull(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

/// Combina a ficha [current] com a resposta [external] da fonte.
///
/// A fonte só corrige: campo ausente lá mantém o valor atual, o nome genérico
/// de produto sem nome não substitui um nome real e foto fora do domínio da
/// fonte é ignorada.
CatalogUpdate catalogUpdateFrom(Product current, Product external) {
  final name = _blankToNull(external.name);
  final image = _blankToNull(external.imageUrl);
  return CatalogUpdate(
    barcode: current.barcode,
    name: name == null || name == offProductNameFallback ? current.name : name,
    brand: _blankToNull(external.brand)?.toLowerCase() ?? current.brand,
    category: _blankToNull(external.category) ?? current.category,
    imageUrl: safeSourceUri(image) == null ? current.imageUrl : image,
  );
}

/// Diferenças entre a ficha atual e [update]; vazio quando nada muda.
List<CatalogChange> catalogChanges(Product current, CatalogUpdate update) {
  final changes = <CatalogChange>[];
  void compare(String label, String? before, String? after, String missing) {
    final a = _blankToNull(before), b = _blankToNull(after);
    if (a == b) return;
    changes.add(
      CatalogChange(label: label, before: a ?? missing, after: b ?? missing),
    );
  }

  compare('Nome', current.name, update.name, 'Sem nome');
  compare('Marca', current.brand, update.brand, 'Marca não informada');
  compare('Categoria', current.category, update.category, 'Sem categoria');
  if (_blankToNull(current.imageUrl) != _blankToNull(update.imageUrl)) {
    changes.add(
      CatalogChange(
        label: 'Foto',
        before: _blankToNull(current.imageUrl) == null
            ? 'Sem foto'
            : 'Foto atual',
        after: 'Nova foto da fonte',
      ),
    );
  }
  return changes;
}

/// Mesmas regras de `public.refresh_product`: código de 8 a 14 dígitos, nome
/// de 1 a 300 caracteres após trim e textos vazios como ausentes.
CatalogUpdate validateCatalogUpdate(CatalogUpdate update) {
  final barcode = update.barcode.trim();
  final name = update.name.trim();
  if (!isOffBarcode(barcode)) {
    throw const AppFailure(
      FailureKind.validation,
      'Só produtos com código de barras de 8 a 14 dígitos podem ser '
      'atualizados pela fonte.',
    );
  }
  if (name.isEmpty || name.runes.length > productNameMaxLength) {
    throw const AppFailure(
      FailureKind.validation,
      'O nome do produto deve ter de 1 a $productNameMaxLength caracteres.',
    );
  }
  return CatalogUpdate(
    barcode: barcode,
    name: name,
    brand: _blankToNull(update.brand)?.toLowerCase(),
    category: _blankToNull(update.category),
    imageUrl: _blankToNull(update.imageUrl),
  );
}

/// Parâmetros de `public.refresh_product`; a função não aceita outros campos.
Map<String, dynamic> catalogUpdateToParams(CatalogUpdate update) => {
  'p_barcode': update.barcode,
  'p_name': update.name,
  'p_brand_key': update.brand,
  'p_category': update.category,
  'p_image_url': update.imageUrl,
};

/// Falha exibível quando o produto foi atualizado há menos de
/// [productRefreshInterval]; [retryAfter] é o tempo que falta.
AppFailure refreshRateLimited(Duration retryAfter) {
  final minutes = (retryAfter.inSeconds / 60).ceil().clamp(1, 60);
  return AppFailure(
    FailureKind.unavailable,
    'Esta ficha foi atualizada há pouco. Tente de novo em $minutes min.',
  );
}
