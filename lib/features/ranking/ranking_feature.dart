// Autoria: Leonardo Volpi (T14). Adaptado à fiação atual do core.
import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

class RankingEntry {
  const RankingEntry({
    required this.product,
    required this.average,
    required this.count,
  });

  final Product product;
  final double average;
  final int count;
}

class RankingData {
  const RankingData({required this.products, required this.reviews});

  final List<Product> products;
  final List<Review> reviews;
}

/// Ordena por média (desc), depois por quantidade (desc) e nome (asc).
/// Produtos sem avaliação ficam de fora; respeita o filtro de categoria.
List<RankingEntry> buildRanking({
  required Iterable<Product> products,
  required Iterable<Review> reviews,
  String? category,
}) {
  final sums = <String, int>{};
  final counts = <String, int>{};

  for (final r in reviews) {
    if (r.rating < 1 || r.rating > 5) continue;
    sums[r.barcode] = (sums[r.barcode] ?? 0) + r.rating;
    counts[r.barcode] = (counts[r.barcode] ?? 0) + 1;
  }

  final entries = <RankingEntry>[];
  for (final p in products) {
    if (category != null && p.category != category) continue;
    final count = counts[p.barcode] ?? 0;
    if (count == 0) continue; // não avaliado fica fora
    entries.add(
      RankingEntry(product: p, average: sums[p.barcode]! / count, count: count),
    );
  }

  entries.sort((a, b) {
    final byAvg = b.average.compareTo(a.average);
    if (byAvg != 0) return byAvg;
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
  });
  return entries;
}

/// Categorias que possuem ao menos um produto avaliado, em ordem alfabética.
List<String> evaluatedCategories(RankingData data) {
  final rated = data.reviews.map((r) => r.barcode).toSet();
  final cats = <String>{
    for (final p in data.products)
      if (p.category != null && rated.contains(p.barcode)) p.category!,
  };
  return cats.toList()..sort();
}

class RankingFeature extends StatelessWidget {
  const RankingFeature({super.key, required this.context});

  final FeatureContext context;

  @override
  Widget build(BuildContext buildContext) {
    final scope = context.scope;
    return RankingView(
      initialCategory: context.product?.category,
      // Escopo "Avaliações da turma": carrega todo o catálogo (sem a busca)
      // e agrega as avaliações de cada produto. Nunca chama repo no build.
      loader: () async {
        final products = await scope.products.search(const ProductQuery());
        final lists = await Future.wait(
          products.map((p) => scope.reviews.forProduct(p.barcode)),
        );
        final reviews = <Review>[for (final list in lists) ...list];
        return RankingData(products: products, reviews: reviews);
      },
      onOpenProduct: context.openProduct,
    );
  }
}

class RankingView extends StatefulWidget {
  const RankingView({
    super.key,
    required this.loader,
    required this.onOpenProduct,
    this.initialCategory,
  });

  final Future<RankingData> Function() loader;
  final void Function(Product product) onOpenProduct;
  final String? initialCategory;

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView> {
  late Future<RankingData> _future;
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _future = widget.loader(); // carrega aqui, nunca dentro do build
  }

  void _reload() => setState(() => _future = widget.loader());

  String _errorMessage(Object error) {
    // AppFailure traz uma mensagem segura para exibir (ver CLIENTES.md).
    if (error is AppFailure) return error.message;
    if (error is FeaturePending) return '$error';
    return 'Não deu para carregar o ranking. Tente de novo.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RankingData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const NaLoading(label: 'Carregando ranking…');
        }
        if (snap.hasError) {
          return NaError(message: _errorMessage(snap.error!), onRetry: _reload);
        }

        final data = snap.data!;
        final categories = evaluatedCategories(data);
        // Se a categoria inicial não tem avaliações, mostra todas.
        final selected = categories.contains(_category) ? _category : null;
        final ranking = buildRanking(
          products: data.products,
          reviews: data.reviews,
          category: selected,
        );

        return NaSection(
          title: 'Ranking de produtos',
          description: 'Avaliações da turma, da maior para a menor média.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: NaSpace.md),
                  child: Wrap(
                    spacing: NaSpace.sm,
                    runSpacing: NaSpace.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        tooltip: 'Todas as categorias',
                        selected: selected == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                      for (final c in categories)
                        ChoiceChip(
                          label: Text(c),
                          tooltip: 'Categoria $c',
                          selected: selected == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                ),
              if (ranking.isEmpty)
                const NaEmpty(
                  title: 'Sem produtos avaliados',
                  message:
                      'Ainda não há avaliações nesta categoria. Avalie um '
                      'produto para vê-lo no ranking.',
                  icon: Icons.emoji_events_outlined,
                )
              else
                for (var i = 0; i < ranking.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NaSpace.sm),
                    child: NaItemCard(
                      leading: _RankBadge(place: i + 1),
                      title: ranking[i].product.name,
                      subtitle: _describeEntry(ranking[i]),
                      onTap: () => widget.onOpenProduct(ranking[i].product),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

String _describeEntry(RankingEntry entry) {
  final average = entry.average.toStringAsFixed(1).replaceAll('.', ',');
  final label = entry.count == 1 ? 'avaliação' : 'avaliações';
  return '$average de 5 · ${entry.count} $label';
}

/// Posição no ranking. O número comunica a ordem — a cor é só reforço.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.place});
  final int place;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$placeº lugar',
    child: ExcludeSemantics(
      child: Text(
        '$placeº',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: place <= 3 ? NaColors.amber : null,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
