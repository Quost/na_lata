import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import 'rating_summary.dart';

class SummaryFeature extends StatefulWidget {
  const SummaryFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<SummaryFeature> createState() => _SummaryFeatureState();
}

class _SummaryFeatureState extends State<SummaryFeature> {
  RatingSummary? _summary;
  String? _error;
  int _generation = 0;

  AppScope get _scope => widget.context.scope;
  Product? get _product => widget.context.product;

  @override
  void initState() {
    super.initState();
    _scope.addListener(_reload);
    final product = _product;
    if (product != null) _fetch(product.barcode, _generation);
  }

  @override
  void didUpdateWidget(SummaryFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.context.product?.barcode != _product?.barcode) {
      _summary = null;
      _reload();
    }
  }

  @override
  void dispose() {
    _scope.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    final product = _product;
    final generation = ++_generation;
    if (product == null) {
      setState(() {
        _summary = null;
        _error = null;
      });
      return;
    }
    setState(() => _error = null);
    _fetch(product.barcode, generation);
  }

  Future<void> _fetch(String barcode, int generation) async {
    try {
      final reviews = await _scope.reviews.forProduct(barcode);
      final summary = summarizeReviews(reviews);
      if (!mounted || generation != _generation) return;
      setState(() => _summary = summary);
    } on AppFailure catch (e) {
      _fail(e.message, generation);
    } on FeaturePending catch (e) {
      _fail('$e', generation);
    } on Exception {
      _fail(
        'Não foi possível carregar as avaliações. Tente novamente.',
        generation,
      );
    }
  }

  void _fail(String message, int generation) {
    if (!mounted || generation != _generation) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext buildContext) =>
      NaSection(title: 'Resumo das avaliações', child: _body());

  Widget _body() {
    if (_product == null) {
      return const NaEmpty(
        title: 'Nenhum produto selecionado',
        message:
            'Abra um produto pela ficha no Catálogo para ver o resumo das '
            'avaliações.',
        icon: Icons.bar_chart,
      );
    }
    if (_error != null) {
      return NaError(message: _error!, onRetry: _reload);
    }
    final summary = _summary;
    if (summary == null) {
      return const NaLoading(label: 'Carregando avaliações…');
    }
    return _SummaryView(summary: summary);
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary});
  final RatingSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NaRatingBadge(average: summary.average, count: summary.count),
      const SizedBox(height: NaSpace.md),
      Text('Total de avaliações: ${summary.count}'),
      if (summary.count == 0) ...[
        const SizedBox(height: NaSpace.xs),
        const Text('Ninguém avaliou este produto ainda.'),
      ],
      const SizedBox(height: NaSpace.md),
      for (final star in [5, 4, 3, 2, 1])
        _HistogramRow(
          star: star,
          count: summary.histogram[star] ?? 0,
          total: summary.count,
        ),
    ],
  );
}

class _HistogramRow extends StatelessWidget {
  const _HistogramRow({
    required this.star,
    required this.count,
    required this.total,
  });
  final int star, count, total;

  @override
  Widget build(BuildContext context) {
    final starsLabel = star == 1 ? 'estrela' : 'estrelas';
    final countLabel = count == 1 ? 'avaliação' : 'avaliações';
    return Semantics(
      label: '$star $starsLabel: $count $countLabel',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: NaSpace.xs),
          child: Row(
            children: [
              Text('$star'),
              const Icon(Icons.star_rounded, size: 16, color: NaColors.amber),
              const SizedBox(width: NaSpace.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(NaRadius.control),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : count / total,
                    minHeight: 8,
                    color: NaColors.amber,
                    backgroundColor: NaColors.border,
                  ),
                ),
              ),
              const SizedBox(width: NaSpace.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24),
                child: Text(
                  '$count',
                  key: Key('histogram-count-$star'),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}