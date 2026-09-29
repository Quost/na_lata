import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import '../moderation/comment_moderator.dart';

/// T09 · Exibir comentários do produto.
///
/// Ordena as avaliações da mais recente para a mais antiga sem alterar a lista
/// recebida. Ordenar é responsabilidade da feature: o repositório pode devolver
/// em qualquer ordem.
List<Review> sortNewestFirst(List<Review> reviews) =>
    [...reviews]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

/// Data curta dd/MM/aaaa, sem depender de pacote de internacionalização.
String formatCommentDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

class CommentsFeature extends StatefulWidget {
  const CommentsFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<CommentsFeature> createState() => _CommentsFeatureState();
}

class _CommentsFeatureState extends State<CommentsFeature> {
  List<Review>? _reviews;
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
  void didUpdateWidget(CommentsFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.context.product?.barcode != _product?.barcode) {
      _reviews = null;
      _reload();
    }
  }

  @override
  void dispose() {
    _scope.removeListener(_reload);
    super.dispose();
  }

  /// refresh()/setQuery() de outro módulo (ex.: publicar avaliação) recarrega.
  void _reload() {
    final product = _product;
    final generation = ++_generation;
    if (product == null) {
      setState(() {
        _reviews = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _reviews = null;
      _error = null;
    });
    _fetch(product.barcode, generation);
  }

  Future<void> _fetch(String barcode, int generation) async {
    try {
      final reviews = await _scope.reviews.forProduct(barcode);
      if (!mounted || generation != _generation) return;
      setState(() => _reviews = sortNewestFirst(reviews));
    } on AppFailure catch (e) {
      _fail(e.message, generation);
    } on FeaturePending catch (e) {
      _fail('$e', generation);
    } on Exception {
      _fail(
        'Não foi possível carregar os comentários. Tente novamente.',
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
    title: 'Comentários do produto',
    description: 'Avaliações da turma, das mais recentes para as mais antigas.',
    child: _body(),
  );

  Widget _body() {
    if (_product == null) {
      return const NaEmpty(
        title: 'Nenhum produto selecionado',
        message:
            'Abra um produto pela ficha no Catálogo para ver os comentários.',
        icon: Icons.forum_outlined,
      );
    }
    if (_error != null) return NaError(message: _error!, onRetry: _reload);
    final reviews = _reviews;
    if (reviews == null) {
      return const NaLoading(label: 'Carregando comentários…');
    }
    if (reviews.isEmpty) {
      return const NaEmpty(
        title: 'Ainda sem comentários',
        message:
            'Este produto ainda não recebeu avaliações. Que tal ser a '
            'primeira pessoa a avaliar?',
        icon: Icons.rate_review_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final review in reviews) _CommentCard(review: review)],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = review.comment.trim();
    // A máscara é só para exibição; o texto original permanece no banco.
    final masked = comment.isEmpty ? null : moderateComment(comment);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.person_outline, size: 20),
                ),
                const SizedBox(width: NaSpace.sm),
                Expanded(
                  child: Text(
                    review.nickname,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: NaSpace.sm),
                Text(
                  formatCommentDate(review.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: NaColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: NaSpace.sm),
            _Stars(rating: review.rating),
            const SizedBox(height: NaSpace.sm),
            if (masked != null)
              Text(masked, style: theme.textTheme.bodyMedium)
            else
              Text(
                'Sem comentário.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: NaColors.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nota em estrelas, com forma (preenchida/contorno) além da cor e rótulo
/// acessível — não depende só de cor.
class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    final label = 'Nota $rating de 5';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var star = 1; star <= 5; star++)
              Icon(
                star <= rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 18,
                color: NaColors.amber,
              ),
          ],
        ),
      ),
    );
  }
}
