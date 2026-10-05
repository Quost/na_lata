import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../core/ui_format.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

/// Avaliação da sessão atual com o produto do catálogo, quando encontrado.
class MyReviewEntry {
  const MyReviewEntry({required this.review, this.product});
  final Review review;
  final Product? product;
}

/// Consulta `mine` (autorização pela sessão/RLS, não por filtro visual) e
/// resolve cada barcode com `byBarcode`. Erros são propagados, nunca viram
/// lista vazia. Produto ausente do catálogo fica com `product == null`.
Future<List<MyReviewEntry>> loadMyReviews(
  ReviewRepository reviews,
  ProductRepository products,
) async {
  final mine = await reviews.mine();
  final barcodes = {for (final r in mine) r.barcode}.toList();
  final found = await Future.wait(barcodes.map(products.byBarcode));
  final byBarcode = {
    for (var i = 0; i < barcodes.length; i++) barcodes[i]: found[i],
  };
  final entries = [
    for (final r in mine)
      MyReviewEntry(review: r, product: byBarcode[r.barcode]),
  ]..sort((a, b) => b.review.createdAt.compareTo(a.review.createdAt));
  return entries;
}

/// Mensagem segura para a UI: sem payload nem stack trace.
String myReviewsErrorMessage(Object error) => switch (error) {
  AppFailure(:final message) => message,
  FeaturePending() => '$error',
  _ => 'Não foi possível carregar suas avaliações.',
};

class MyReviewsFeature extends StatefulWidget {
  const MyReviewsFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<MyReviewsFeature> createState() => _MyReviewsFeatureState();
}

class _MyReviewsFeatureState extends State<MyReviewsFeature> {
  late AppScope _scope;
  List<MyReviewEntry>? _entries;
  String? _error;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scope = widget.context.scope;
    _scope.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(MyReviewsFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.context.scope, widget.context.scope)) {
      _scope.removeListener(_load);
      _scope = widget.context.scope;
      _scope.addListener(_load);
      _load();
    }
  }

  @override
  void dispose() {
    _scope.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    // Descarta respostas antigas quando outra carga começa (ex.: refresh).
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await loadMyReviews(_scope.reviews, _scope.products);
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error, stack) {
      if (error is Error) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = myReviewsErrorMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Minhas avaliações',
    description: 'Somente as avaliações feitas nesta sessão.',
    child: _body(),
  );

  Widget _body() {
    if (_loading) return const NaLoading(label: 'Carregando suas avaliações…');
    if (_error != null) return NaError(message: _error!, onRetry: _load);
    final entries = _entries ?? const [];
    if (entries.isEmpty) {
      return const NaEmpty(
        title: 'Você ainda não avaliou nada',
        message: 'Abra um produto no Catálogo e deixe sua nota.',
        icon: Icons.rate_review_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Atualizar minhas avaliações',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ),
        for (final entry in entries) _MyReviewTile(entry: entry, open: _open),
      ],
    );
  }

  void _open(Product product) => widget.context.openProduct(product);
}

class _MyReviewTile extends StatelessWidget {
  const _MyReviewTile({required this.entry, required this.open});
  final MyReviewEntry entry;
  final void Function(Product) open;

  @override
  Widget build(BuildContext context) {
    final review = entry.review;
    final product = entry.product;
    final comment = review.comment.trim();
    final subtitle = [
      'Nota ${review.rating} de 5 · ${_date(review.createdAt)}',
      if (comment.isNotEmpty) '“$comment”',
    ].join('\n');
    final leading = Icon(
      Icons.star_rounded,
      color: NaColors.amber,
      semanticLabel: 'Nota ${review.rating}',
    );
    if (product == null) {
      return Card(
        child: ListTile(
          leading: leading,
          title: Text('Produto ${review.barcode}'),
          subtitle: Text('$subtitle\nProduto não encontrado no catálogo.'),
        ),
      );
    }
    return NaItemCard(
      title: product.name,
      subtitle: subtitle,
      leading: leading,
      onTap: () => open(product),
    );
  }

  static String _date(DateTime d) => formatShortDate(d);
}
