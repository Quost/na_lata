import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../design_system/na_lata_ui.dart';

class FiltersFeature extends StatefulWidget {
  const FiltersFeature({super.key, required this.context});

  final FeatureContext context;

  @override
  State<FiltersFeature> createState() => _FiltersFeatureState();
}

class _FiltersFeatureState extends State<FiltersFeature> {
  late final TextEditingController _textController;
  late ProductQuery _query;
  late Future<List<Product>> _catalogFuture;
  late Future<List<Product>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _query = widget.context.scope.query;
    _textController = TextEditingController(text: _query.text);
    _catalogFuture = _loadCatalog();
    _resultsFuture = _loadResults(_query);
  }

  @override
  void didUpdateWidget(covariant FiltersFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scope = widget.context.scope;
    final scopeChanged = !identical(oldWidget.context.scope, scope);
    if (scopeChanged) {
      _catalogFuture = _loadCatalog();
    }

    final updatedQuery = scope.query;
    final queryChanged = !_sameQuery(updatedQuery, _query);
    if (queryChanged) {
      _textController.value = TextEditingValue(
        text: updatedQuery.text,
        selection: TextSelection.collapsed(offset: updatedQuery.text.length),
      );
    }
    if (scopeChanged || queryChanged) {
      _query = updatedQuery;
      _resultsFuture = _loadResults(updatedQuery);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<List<Product>> _loadCatalog() => Future<List<Product>>.sync(
        () => widget.context.scope.products.search(const ProductQuery()),
  );

  Future<List<Product>> _loadResults(ProductQuery query) =>
      Future<List<Product>>.sync(
            () => widget.context.scope.products.search(query),
      );

  bool _sameQuery(ProductQuery first, ProductQuery second) =>
      first.text == second.text &&
          first.brand == second.brand &&
          first.category == second.category;

  void _updateQuery({
    String? text,
    String? brand,
    String? category,
    bool clearBrand = false,
    bool clearCategory = false,
  }) {
    final next = ProductQuery(
      text: text ?? _query.text,
      brand: clearBrand ? null : brand ?? _query.brand,
      category: clearCategory ? null : category ?? _query.category,
    );
    if (_sameQuery(next, _query)) return;

    setState(() {
      _query = next;
      _resultsFuture = _loadResults(next);
    });
    widget.context.scope.setQuery(next);
  }

  void _clearFilters() {
    _textController.clear();
    _updateQuery(text: '', clearBrand: true, clearCategory: true);
  }

  void _retryCatalog() {
    setState(() => _catalogFuture = _loadCatalog());
  }

  void _retryResults() {
    setState(() => _resultsFuture = _loadResults(_query));
  }

  @override
  Widget build(BuildContext context) => NaContent(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NaSection(
          title: 'Filtrar produtos',
          description:
          'Combine busca, marca e categoria. As opções vêm do catálogo.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.context.product case final product?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Produto em contexto: ${product.name}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Nenhum produto selecionado. Os filtros continuam disponíveis para todo o catálogo.',
                  ),
                ),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Buscar produto',
                  hintText: 'Digite o nome do produto',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => _updateQuery(text: value.trim()),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Product>>(
                future: _catalogFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return NaError(
                      message: '${snapshot.error}',
                      onRetry: _retryCatalog,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const NaLoading(label: 'Carregando opções…');
                  }

                  final options = FilterOptions.fromProducts(snapshot.data!);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _dropdownValue(
                          _query.brand,
                          options.brands,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Marca',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todas as marcas'),
                          ),
                          ...options.brands.map(
                                (brand) => DropdownMenuItem<String>(
                              value: brand,
                              child: Text(brand),
                            ),
                          ),
                        ],
                        onChanged: (value) => _updateQuery(
                          brand: value,
                          clearBrand: value == null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _dropdownValue(
                          _query.category,
                          options.categories,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todas as categorias'),
                          ),
                          ...options.categories.map(
                                (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],
                        onChanged: (value) => _updateQuery(
                          category: value,
                          clearCategory: value == null,
                        ),
                      ),
                      if (options.brands.isEmpty ||
                          options.categories.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _optionsEmptyMessage(options),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _query.text.isEmpty &&
                      _query.brand == null &&
                      _query.category == null
                      ? null
                      : _clearFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpar filtros'),
                ),
              ),
            ],
          ),
        ),
        NaSection(
          title: 'Resultados',
          description: _queryDescription(_query),
          child: FutureBuilder<List<Product>>(
            future: _resultsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return NaError(
                  message: '${snapshot.error}',
                  onRetry: _retryResults,
                );
              }
              if (!snapshot.hasData) {
                return const NaLoading(label: 'Buscando produtos…');
              }
              if (snapshot.data!.isEmpty) {
                return NaEmpty(
                  title: 'Nenhum produto encontrado',
                  message: _query.text.isEmpty &&
                      _query.brand == null &&
                      _query.category == null
                      ? 'O catálogo está vazio.'
                      : 'Tente ajustar a busca ou limpar os filtros.',
                  action: TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Limpar filtros'),
                  ),
                );
              }

              return Column(
                children: snapshot.data!
                    .map(
                      (product) => NaItemCard(
                    title: product.name,
                    subtitle:
                    '${_displayValue(product.brand, 'Marca não informada')} • '
                        '${_displayValue(product.category, 'Sem categoria')}',
                    onTap: () => widget.context.openProduct(product),
                  ),
                )
                    .toList(),
              );
            },
          ),
        ),
      ],
    ),
  );

  String? _dropdownValue(String? selected, List<String> options) =>
      selected != null && options.contains(selected) ? selected : null;

  String _displayValue(String? value, String fallback) =>
      value == null || value.trim().isEmpty ? fallback : value.trim();

  String _optionsEmptyMessage(FilterOptions options) {
    if (options.brands.isEmpty && options.categories.isEmpty) {
      return 'O catálogo ainda não tem marcas ou categorias informadas.';
    }
    return options.brands.isEmpty
        ? 'O catálogo ainda não tem marcas informadas.'
        : 'O catálogo ainda não tem categorias informadas.';
  }

  String _queryDescription(ProductQuery query) {
    final activeFilters = <String>[];
    if (query.text.isNotEmpty) activeFilters.add('busca: "${query.text}"');
    if (query.brand != null) activeFilters.add('marca: ${query.brand}');
    if (query.category != null) {
      activeFilters.add('categoria: ${query.category}');
    }
    return activeFilters.isEmpty
        ? 'Todos os produtos do catálogo'
        : activeFilters.join(' · ');
  }
}

class FilterOptions {
  const FilterOptions({required this.brands, required this.categories});

  factory FilterOptions.fromProducts(Iterable<Product> products) {
    final brands = <String>{};
    final categories = <String>{};
    for (final product in products) {
      final brand = product.brand?.trim();
      final category = product.category?.trim();
      if (brand != null && brand.isNotEmpty) brands.add(brand);
      if (category != null && category.isNotEmpty) categories.add(category);
    }
    return FilterOptions(
      brands: (brands.toList()..sort()),
      categories: (categories.toList()..sort()),
    );
  }

  final List<String> brands;
  final List<String> categories;
}
