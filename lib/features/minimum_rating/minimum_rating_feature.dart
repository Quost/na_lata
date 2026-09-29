import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import 'minimum_rating_filter.dart';

class MinimumRatingFeature extends StatefulWidget {
  const MinimumRatingFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<MinimumRatingFeature> createState() => _MinimumRatingFeatureState();
}

class _MinimumRatingFeatureState extends State<MinimumRatingFeature> {
  int _minimum = 4;
  List<RatedProduct>? _items;
  String? _error;
  int _generation = 0;

  AppScope get _scope => widget.context.scope;

  @override
  void initState() {
    super.initState();
    _scope.addListener(_reload);
    _fetch(_generation);
  }

  @override
  void dispose() {
    _scope.removeListener(_reload);
    super.dispose();
  }

  /// Chamado por refresh() e setQuery(): recarrega com a consulta atual.
  void _reload() {
    final generation = ++_generation;
    setState(() {
      _items = null;
      _error = null;
    });
    _fetch(generation);
  }

  Future<void> _fetch(int generation) async {
    try {
      final items = await loadRatedProducts(
        _scope.query,
        products: _scope.products,
        reviews: _scope.reviews,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _items = items);
    } on AppFailure catch (e) {
      _fail(e.message, generation);
    } on FeaturePending catch (e) {
      _fail('$e', generation);
    } on Exception {
      _fail(
        'Não foi possível carregar os produtos. Tente novamente.',
        generation,
      );
    }
  }

  void _fail(String message, int generation) {
    if (!mounted || generation != _generation) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Filtrar por nota mínima',
    description:
        'Produtos avaliados pela turma com média igual ou acima da '
        'nota escolhida. Respeita a busca e os filtros do Catálogo.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MinimumPicker(
          value: _minimum,
          onChanged: (value) => setState(() => _minimum = value),
        ),
        const SizedBox(height: NaSpace.sm),
        Text(
          _describeQuery(_scope.query),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: NaSpace.md),
        _body(),
      ],
    ),
  );

  Widget _body() {
    if (_error != null) return NaError(message: _error!, onRetry: _reload);
    final items = _items;
    if (items == null) return const NaLoading(label: 'Carregando notas…');
    final filtered = filterByMinimumRating(items, _minimum);
    if (filtered.isEmpty) {
      return NaEmpty(
        title: 'Nenhum produto com nota $_minimum ou mais',
        message:
            'Escolha uma nota menor, ajuste a busca do Catálogo ou '
            'avalie um produto.',
        icon: Icons.star_outline_rounded,
      );
    }
    return Column(
      children: [
        for (final item in filtered)
          NaItemCard(
            title: item.product.name,
            subtitle:
                '${item.product.brand ?? 'Marca não informada'} • '
                '${_formatRating(item.summary)}',
            leading: const Icon(Icons.star_rounded, color: NaColors.amber),
            onTap: () => widget.context.openProduct(item.product),
          ),
      ],
    );
  }
}

String _formatRating(RatingSummary summary) {
  final average = summary.average!.toStringAsFixed(1).replaceAll('.', ',');
  final label = summary.count == 1 ? 'avaliação' : 'avaliações';
  return '$average de 5 · ${summary.count} $label';
}

String _describeQuery(ProductQuery query) {
  final parts = [
    if (query.text.trim().isNotEmpty) 'busca "${query.text.trim()}"',
    if (query.brand != null) 'marca ${query.brand}',
    if (query.category != null) 'categoria ${query.category}',
  ];
  return parts.isEmpty
      ? 'Considerando todo o catálogo.'
      : 'Considerando ${parts.join(', ')}.';
}

class _MinimumPicker extends StatelessWidget {
  const _MinimumPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: NaSpace.sm,
    runSpacing: NaSpace.sm,
    children: [
      for (var star = 1; star <= 5; star++)
        ChoiceChip(
          label: Text('$star+'),
          avatar: const Icon(
            Icons.star_rounded,
            size: 18,
            color: NaColors.amber,
          ),
          tooltip: 'Nota $star ou mais',
          selected: value == star,
          onSelected: (_) => onChanged(star),
        ),
    ],
  );
}
