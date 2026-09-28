import 'package:flutter/material.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';


import 'package:na_lata/core/core.dart';


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
    entries.add(RankingEntry(
      product: p,
      average: sums[p.barcode]! / count,
      count: count,
    ));
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

List<String> evaluatedCategories(RankingData data) {
  final rated = data.reviews.map((r) => r.barcode).toSet();
  final cats = <String>{
    for (final p in data.products)
      if (p.category != null && rated.contains(p.barcode)) p.category!,
  };
  return cats.toList()..sort();
}

class RankingFeature extends StatelessWidget {
  // TODO: conferir com o feature_registry como o módulo é instanciado.
  const RankingFeature({super.key, required this.featureContext});

  final FeatureContext featureContext;

  @override
  Widget build(BuildContext context) {
    final scope = featureContext.scope;
    return RankingView(

      initialCategory: featureContext.product?.category,
      loader: () async {
        // TODO: trocar pelos métodos reais dos repositórios (contratos do
        // AppScope). Em modo demo o fake em memória responde; em Supabase o
        // repositório fica pendente até T02/T08 e deve lançar FeaturePending.
        final products = await scope.products.listAll();
        final reviews = await scope.reviews.listAll();
        return RankingData(products: products, reviews: reviews);
      },
      onOpenProduct: featureContext.openProduct,
    );
  }
}

class RankingView extends StatefulWidget {
  const RankingView({
    super.key,
    required this.loader,
    this.initialCategory,
    this.onOpenProduct,
  });

  final Future<RankingData> Function() loader;
  final String? initialCategory;
  final void Function(Product product)? onOpenProduct;

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
    return 'Não deu para carregar o ranking. Tente de novo.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RankingData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const NaLoading();
        }
        if (snap.hasError) {
          // TODO: conferir os parâmetros reais de NaError na galeria do app.
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

        return NaContent(
          child: ListView(
            padding: NaSpace.page,
            children: [
              NaSection(
                title: 'Ranking de produtos',
                description: 'Avaliações da turma',
                child: categories.isEmpty
                    ? const SizedBox.shrink()
                    : Wrap(
                        spacing: NaSpace.sm,
                        runSpacing: NaSpace.sm,
                        children: [
                          FilterChip(
                            label: const Text('Todas'),
                            selected: selected == null,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                          for (final c in categories)
                            FilterChip(
                              label: Text(c),
                              selected: selected == c,
                              onSelected: (_) => setState(() => _category = c),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: NaSpace.lg),
              if (ranking.isEmpty)
                // TODO: conferir parâmetros reais de NaEmpty.
                const NaEmpty(
                  message: 'Ainda não há produtos avaliados nesta categoria.',
                )
              else
                for (var i = 0; i < ranking.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NaSpace.sm),
                    child: NaItemCard(
                      leading: Text('${i + 1}º',
                          style: Theme.of(context).textTheme.titleMedium),
                      title: ranking[i].product.name,
                      subtitle:
                          '${ranking[i].count} ${ranking[i].count == 1 ? 'avaliação' : 'avaliações'}',
                      onTap: widget.onOpenProduct == null
                          ? null
                          : () => widget.onOpenProduct!(ranking[i].product),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}