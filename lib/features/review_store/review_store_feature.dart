import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../data/supabase_reviews.dart' show reviewCommentMaxLength;
import '../../design_system/na_lata_ui.dart';
import '../moderation/comment_moderator.dart';

/// Diagnóstico da T08: grava e consulta avaliações pelo ReviewRepository.
class ReviewStoreFeature extends StatefulWidget {
  const ReviewStoreFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<ReviewStoreFeature> createState() => _ReviewStoreFeatureState();
}

class _ReviewStoreFeatureState extends State<ReviewStoreFeature> {
  late final _barcode = TextEditingController(
    text: widget.context.product?.barcode ?? '',
  );
  final _comment = TextEditingController();
  int? _rating;
  bool _saving = false;
  String? _saveError, _saveMessage;

  /// Consulta exibida: descrição, execução (para "tentar novamente") e resultado.
  String? _queryLabel;
  Future<List<Review>> Function()? _lastQuery;
  bool _loading = false;
  List<Review>? _reviews;
  String? _queryError;

  ReviewRepository get _repo => widget.context.scope.reviews;

  @override
  void dispose() {
    _barcode.dispose();
    _comment.dispose();
    super.dispose();
  }

  String? _failureMessage(Object error) => switch (error) {
    AppFailure(:final message) => message,
    FeaturePending() => error.toString(),
    _ => null,
  };

  Future<void> _run(String label, Future<List<Review>> Function() query) async {
    setState(() {
      _queryLabel = label;
      _lastQuery = query;
      _loading = true;
      _queryError = null;
      _reviews = null;
    });
    try {
      final reviews = await query();
      if (!mounted) return;
      setState(() => _reviews = reviews);
    } catch (error) {
      final message = _failureMessage(error);
      if (message == null) rethrow;
      if (!mounted) return;
      setState(() => _queryError = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadProduct() {
    final barcode = _barcode.text.trim();
    if (barcode.isEmpty) {
      setState(() {
        _queryLabel = 'forProduct(—)';
        _lastQuery = null;
        _reviews = null;
        _queryError = 'Informe um código de barras para consultar.';
      });
      return;
    }
    _run('forProduct("$barcode")', () => _repo.forProduct(barcode));
  }

  void _loadMine() => _run('mine()', _repo.mine);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
      _saveMessage = null;
    });
    try {
      // Nota ausente vira 0 e é rejeitada pelo repositório (validação única).
      await _repo.save(
        ReviewDraft(
          barcode: _barcode.text,
          rating: _rating ?? 0,
          comment: _comment.text,
        ),
      );
      if (!mounted) return;
      setState(() => _saveMessage = 'Avaliação salva.');
      widget.context.scope.refresh();
      _loadProduct();
    } catch (error) {
      final message = _failureMessage(error);
      if (message == null) rethrow;
      if (!mounted) return;
      setState(() => _saveError = message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.context.scope;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: NaSection(
          title: 'Persistir e consultar avaliações',
          description:
              'Modo ${scope.isDemo ? 'demonstração (memória)' : 'Supabase'}. '
              'A autoria vem da sessão; uma avaliação por produto e usuário.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.context.product == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: NaSpace.md),
                  child: Text(
                    'Nenhum produto aberto. Abra uma ficha do catálogo ou '
                    'digite um código${scope.isDemo ? ' (ex.: demo-leite-1)' : ''}.',
                  ),
                ),
              TextField(
                controller: _barcode,
                decoration: const InputDecoration(
                  labelText: 'Código de barras',
                ),
              ),
              const SizedBox(height: NaSpace.md),
              Text('Nota', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: NaSpace.xs),
              SegmentedButton<int>(
                segments: [
                  for (var n = 1; n <= 5; n++)
                    ButtonSegment(value: n, label: Text('$n')),
                ],
                selected: {?_rating},
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _rating = value.firstOrNull),
              ),
              const SizedBox(height: NaSpace.md),
              TextField(
                controller: _comment,
                minLines: 2,
                maxLines: 4,
                // Sem bloqueio para demonstrar a rejeição do limite.
                maxLength: reviewCommentMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                decoration: const InputDecoration(
                  labelText: 'Comentário (opcional)',
                ),
              ),
              const SizedBox(height: NaSpace.sm),
              NaButton(
                label: 'Salvar avaliação',
                loading: _saving,
                onPressed: _save,
              ),
              if (_saveError != null) ...[
                const SizedBox(height: NaSpace.sm),
                Text(
                  'Erro: $_saveError',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_saveMessage != null) ...[
                const SizedBox(height: NaSpace.sm),
                Text(_saveMessage!),
              ],
              const SizedBox(height: NaSpace.lg),
              Wrap(
                spacing: NaSpace.sm,
                runSpacing: NaSpace.sm,
                children: [
                  OutlinedButton(
                    onPressed: _loading ? null : _loadProduct,
                    child: const Text('Avaliações do produto'),
                  ),
                  OutlinedButton(
                    onPressed: _loading ? null : _loadMine,
                    child: const Text('Minhas avaliações'),
                  ),
                ],
              ),
              if (_queryLabel != null) ...[
                const SizedBox(height: NaSpace.md),
                Text(
                  'Consulta: $_queryLabel'
                  '${_reviews != null ? ' → ${_reviews!.length} resultado(s)' : ''}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                _results(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _results() {
    if (_loading) return const NaLoading(label: 'Consultando avaliações…');
    if (_queryError != null) {
      final retry = _lastQuery;
      return retry == null
          ? NaEmpty(
              title: 'Consulta incompleta',
              message: _queryError!,
              icon: Icons.info_outline,
            )
          : NaError(
              message: _queryError!,
              onRetry: () => _run(_queryLabel!, retry),
            );
    }
    final reviews = _reviews;
    if (reviews == null) return const SizedBox.shrink();
    if (reviews.isEmpty) {
      return const NaEmpty(
        title: 'Nenhuma avaliação',
        message: 'Ainda não há avaliações para esta consulta.',
        icon: Icons.rate_review_outlined,
      );
    }
    return Column(children: [for (final r in reviews) _ReviewTile(review: r)]);
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Review review;
  @override
  Widget build(BuildContext context) {
    final comment = review.comment.isEmpty
        ? '(sem comentário)'
        : moderateComment(review.comment);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.star_rounded, color: NaColors.amber),
      title: Text('${review.nickname} · nota ${review.rating} de 5'),
      subtitle: Text('$comment\nProduto: ${review.barcode}'),
      isThreeLine: true,
    );
  }
}
