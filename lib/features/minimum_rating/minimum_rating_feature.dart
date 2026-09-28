import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

class MinimumRatingFeature extends StatefulWidget {
  const MinimumRatingFeature({super.key, required this.context});

  final FeatureContext context;

  @override
  State<MinimumRatingFeature> createState() => _MinimumRatingFeatureState();
}

class _MinimumRatingFeatureState extends State<MinimumRatingFeature> {
  late AppScope _scope;
  late ProductQuery _query;
  late Future<List<_RatedProduct>> _resultsFuture;
  int _minimumRating = 1;
  bool _showErrorScenario = false;

  @override
  void initState() {
    super.initState();
    _scope = widget.context.scope;
    _query = _scope.query;
    _scope.addListener(_onScopeChanged);
    _resultsFuture = _loadResults(_scope, _query);
  }

  @override
  void didUpdateWidget(covariant MinimumRatingFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedScope = widget.context.scope;
    if (!identical(updatedScope, _scope)) {
      _scope.removeListener(_onScopeChanged);
      _scope = updatedScope;
      _scope.addListener(_onScopeChanged);
      _query = _scope.query;
      _showErrorScenario = false;
      _resultsFuture = _loadResults(_scope, _query);
    }
  }

  @override
  void dispose() {
    _scope.removeListener(_onScopeChanged);
    super.dispose();
  }

  void _onScopeChanged() {
    final updatedQuery = _scope.query;
    if (_sameQuery(updatedQuery, _query)) return;

    setState(() {
      _query = updatedQuery;
      _showErrorScenario = false;
      _resultsFuture = _loadResults(_scope, updatedQuery);
    });
  }

  Future<List<_RatedProduct>> _loadResults(
    AppScope scope,
    ProductQuery query,
  ) async {
    final products = await scope.products.search(query);
    return Future.wait(
      products.map((product) async {
        final reviews = await scope.reviews.forProduct(product.barcode);
        return _RatedProduct.fromReviews(product, reviews);
      }),
    );
  }

  bool _sameQuery(ProductQuery first, ProductQuery second) =>
      first.text == second.text &&
      first.brand == second.brand &&
      first.category == second.category;

  void _retry() {
    setState(() {
      _showErrorScenario = false;
      _resultsFuture = _loadResults(_scope, _query);
    });
  }

  void _showSimulatedError() {
    setState(() {
      _showErrorScenario = true;
      _resultsFuture = Future<List<_RatedProduct>>.error(
        const _WorkshopError(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => NaContent(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NaSection(
          title: 'Filtrar por nota mínima',
          description:
              'Os produtos são pesquisados com os filtros atuais e só aparecem '
              'quando têm avaliações e atingem a nota selecionada.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _parameters(context),
              const SizedBox(height: 16),
              Text(
                'Nota mínima',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var rating = 1; rating <= 5; rating++)
                    FilterChip(
                      label: Text('$rating+'),
                      selected: _minimumRating == rating,
                      onSelected: (_) =>
                          setState(() => _minimumRating = rating),
                      avatar: const Icon(Icons.star_rounded, size: 18),
                    ),
                ],
              ),
            ],
          ),
        ),
        NaSection(
          title: 'Resultados filtrados',
          description:
              'Busca: ${_query.text.trim().isEmpty ? 'todos os produtos' : _query.text.trim()}'
              ' · Nota mínima: $_minimumRating de 5',
          child: FutureBuilder<List<_RatedProduct>>(
            future: _resultsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return NaError(
                  message: _errorMessage(snapshot.error),
                  onRetry: _retry,
                );
              }
              if (!snapshot.hasData) {
                return const NaLoading(label: 'Consultando produtos e notas…');
              }

              final results = snapshot.data!
                  .where(
                    (entry) =>
                        entry.average != null &&
                        entry.average! >= _minimumRating,
                  )
                  .toList();
              if (results.isEmpty) {
                return NaEmpty(
                  title: 'Nenhum produto atinge essa nota',
                  message:
                      'Não há produtos avaliados com média de $_minimumRating '
                      'ou mais para a busca atual.',
                );
              }

              return Column(
                children: results
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: NaItemCard(
                          title: entry.product.name,
                          subtitle:
                              '${entry.product.brand ?? 'Marca não informada'}'
                              ' · ${entry.average!.toStringAsFixed(1).replaceAll('.', ',')}'
                              ' de 5 · ${entry.count} avaliações',
                          leading: const Icon(
                            Icons.star_rounded,
                            color: NaColors.amber,
                          ),
                          onTap: () =>
                              widget.context.openProduct(entry.product),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        NaSection(
          title: 'Demonstração da Oficina',
          description:
              'Parâmetros e resultados acima usam os repositórios injetados. '
              'Em modo demonstração, as avaliações fictícias servem como '
              'fixtures enquanto o resumo T10 não está integrado.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _showErrorScenario
                    ? 'Cenário ativo: falha simulada na consulta. Use “Tentar '
                          'novamente” para voltar aos dados.'
                    : 'Também é possível conferir o estado de erro sem alterar '
                          'os dados do catálogo.',
              ),
              const SizedBox(height: 8),
              if (_showErrorScenario)
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Sair do cenário de erro'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _showSimulatedError,
                  icon: const Icon(Icons.error_outline),
                  label: const Text('Demonstrar cenário de erro'),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _parameters(BuildContext context) {
    final product = widget.context.product;
    final queryText = _query.text.trim();
    return Container(
      padding: const EdgeInsets.all(NaSpace.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(NaRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parâmetros de entrada',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Busca: ${queryText.isEmpty ? 'sem filtro de texto' : queryText}',
          ),
          Text('Marca: ${_query.brand ?? 'todas'}'),
          Text('Categoria: ${_query.category ?? 'todas'}'),
          Text('Nota mínima: $_minimumRating de 5'),
          Text(
            product == null
                ? 'Produto em contexto: nenhum (Oficina)'
                : 'Produto em contexto: ${product.name}',
          ),
        ],
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is AppFailure) return error.message;
    if (error is FeaturePending) return error.toString();
    if (error is _WorkshopError) {
      return 'Cenário simulado da Oficina: a consulta falhou. '
          'Tente novamente para carregar os dados.';
    }
    return 'Ocorreu um erro ao carregar os produtos e as avaliações. '
        'Tente novamente.';
  }
}

class _RatedProduct {
  const _RatedProduct({
    required this.product,
    required this.average,
    required this.count,
  });

  factory _RatedProduct.fromReviews(Product product, List<Review> reviews) {
    final validRatings = reviews
        .map((review) => review.rating)
        .where((rating) => rating >= 1 && rating <= 5)
        .toList();
    if (validRatings.isEmpty) {
      return _RatedProduct(product: product, average: null, count: 0);
    }

    final total = validRatings.fold<int>(0, (sum, rating) => sum + rating);
    return _RatedProduct(
      product: product,
      average: total / validRatings.length,
      count: validRatings.length,
    );
  }

  final Product product;
  final double? average;
  final int count;
}

class _WorkshopError implements Exception {
  const _WorkshopError();
}
