import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

/// T12 · Filtrar por marca e categoria.
///
/// Monta a consulta preservando o texto de busca atual e combinando marca e
/// categoria. Passar `null` em uma dimensão remove aquele filtro.
ProductQuery buildFilterQuery({
  required String text,
  String? brand,
  String? category,
}) => ProductQuery(text: text, brand: brand, category: category);

/// Opções distintas e ordenadas extraídas do catálogo. Marca/categoria
/// ausentes ou em branco são ignoradas — não viram opção e não quebram nada.
class FilterOptions {
  const FilterOptions({required this.brands, required this.categories});
  final List<String> brands;
  final List<String> categories;
  bool get isEmpty => brands.isEmpty && categories.isEmpty;
}

FilterOptions extractFilterOptions(List<Product> products) {
  final brands = <String>{};
  final categories = <String>{};
  for (final product in products) {
    final brand = product.brand?.trim();
    if (brand != null && brand.isNotEmpty) brands.add(brand);
    final category = product.category?.trim();
    if (category != null && category.isNotEmpty) categories.add(category);
  }
  int byLabel(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  return FilterOptions(
    brands: brands.toList()..sort(byLabel),
    categories: categories.toList()..sort(byLabel),
  );
}

class FiltersFeature extends StatefulWidget {
  const FiltersFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<FiltersFeature> createState() => _FiltersFeatureState();
}

class _FiltersFeatureState extends State<FiltersFeature> {
  FilterOptions? _options;
  String? _error;
  int _generation = 0;

  AppScope get _scope => widget.context.scope;

  @override
  void initState() {
    super.initState();
    // Redesenha para refletir a seleção atual de scope.query (inclusive quando
    // o Catálogo muda o texto ou outro módulo limpa os filtros).
    _scope.addListener(_onScopeChanged);
    _fetch(_generation);
  }

  @override
  void dispose() {
    _scope.removeListener(_onScopeChanged);
    super.dispose();
  }

  void _onScopeChanged() {
    if (mounted) setState(() {});
  }

  void _reload() {
    final generation = ++_generation;
    setState(() {
      _options = null;
      _error = null;
    });
    _fetch(generation);
  }

  Future<void> _fetch(int generation) async {
    try {
      // Universo de opções: catálogo inteiro, sem texto nem filtros.
      final products = await _scope.products.search(const ProductQuery());
      if (!mounted || generation != _generation) return;
      setState(() => _options = extractFilterOptions(products));
    } on AppFailure catch (e) {
      _fail(e.message, generation);
    } on FeaturePending catch (e) {
      _fail('$e', generation);
    } on Exception {
      _fail(
        'Não foi possível carregar os filtros. Tente novamente.',
        generation,
      );
    }
  }

  void _fail(String message, int generation) {
    if (!mounted || generation != _generation) return;
    setState(() => _error = message);
  }

  void _apply({String? brand, String? category}) => _scope.setQuery(
    buildFilterQuery(text: _scope.query.text, brand: brand, category: category),
  );

  void _clear() => _scope.setQuery(buildFilterQuery(text: _scope.query.text));

  @override
  Widget build(BuildContext context) {
    final query = _scope.query;
    final activeCount =
        (query.brand != null ? 1 : 0) + (query.category != null ? 1 : 0);
    return NaSection(
      title: 'Filtrar por marca e categoria',
      description:
          'Combine marca e categoria com a busca do Catálogo. Toque de novo '
          'em um filtro para removê-lo.',
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          leading: const Icon(Icons.filter_alt_outlined),
          title: Text(
            activeCount == 0
                ? 'Nenhum filtro aplicado'
                : '$activeCount filtro${activeCount == 1 ? '' : 's'} ativo'
                      '${activeCount == 1 ? '' : 's'}',
          ),
          subtitle: Text(
            _describeSelection(query),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Mantém aberto quando há filtro ativo, para dar visibilidade.
          initiallyExpanded: activeCount > 0,
          childrenPadding: const EdgeInsets.fromLTRB(
            NaSpace.lg,
            0,
            NaSpace.lg,
            NaSpace.lg,
          ),
          children: [_body(context)],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) return NaError(message: _error!, onRetry: _reload);
    final options = _options;
    if (options == null) return const NaLoading(label: 'Carregando filtros…');
    if (options.isEmpty) {
      return const NaEmpty(
        title: 'Nada para filtrar',
        message: 'O catálogo ainda não tem marcas ou categorias cadastradas.',
        icon: Icons.filter_alt_off_outlined,
      );
    }
    final query = _scope.query;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.brands.isNotEmpty) ...[
          Text('Marca', style: theme.textTheme.titleSmall),
          const SizedBox(height: NaSpace.sm),
          _ChipGroup(
            dimension: 'marca',
            values: options.brands,
            selected: query.brand,
            onChanged: (brand) =>
                _apply(brand: brand, category: query.category),
          ),
          const SizedBox(height: NaSpace.lg),
        ],
        if (options.categories.isNotEmpty) ...[
          Text('Categoria', style: theme.textTheme.titleSmall),
          const SizedBox(height: NaSpace.sm),
          _ChipGroup(
            dimension: 'categoria',
            values: options.categories,
            selected: query.category,
            onChanged: (category) =>
                _apply(brand: query.brand, category: category),
          ),
          const SizedBox(height: NaSpace.lg),
        ],
        Text(
          _describeSelection(query),
          style: theme.textTheme.bodySmall?.copyWith(color: NaColors.muted),
        ),
        const SizedBox(height: NaSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: query.brand == null && query.category == null
                ? null
                : _clear,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpar filtros'),
          ),
        ),
      ],
    );
  }

  String _describeSelection(ProductQuery query) {
    final active = [
      if (query.brand != null) 'marca ${query.brand}',
      if (query.category != null) 'categoria ${query.category}',
    ];
    final search = query.text.trim();
    if (active.isEmpty) {
      return search.isEmpty
          ? 'Nenhum filtro aplicado. Mostrando todo o catálogo.'
          : 'Nenhum filtro aplicado. Mantendo a busca “$search”.';
    }
    final base = 'Filtrando por ${active.join(' e ')}';
    return search.isEmpty ? '$base.' : '$base, junto da busca “$search”.';
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.dimension,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final String dimension;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: NaSpace.sm,
    runSpacing: NaSpace.sm,
    children: [
      for (final value in values)
        FilterChip(
          label: Text(value),
          tooltip: selected == value
              ? 'Remover filtro de $dimension $value'
              : 'Filtrar por $dimension $value',
          selected: selected == value,
          onSelected: (isSelected) => onChanged(isSelected ? value : null),
        ),
    ],
  );
}
