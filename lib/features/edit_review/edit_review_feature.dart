import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import '../review_form/review_validation.dart';
import 'edit_review_logic.dart';

class EditReviewFeature extends StatefulWidget {
  const EditReviewFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<EditReviewFeature> createState() => _EditReviewFeatureState();
}

class _EditReviewFeatureState extends State<EditReviewFeature> {
  final _comment = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;
  String? _ratingError;
  String? _commentError;
  Review? _original;
  int? _rating;
  int _generation = 0;

  AppScope get _scope => widget.context.scope;
  Product? get _product => widget.context.product;

  bool get _dirty {
    final original = _original;
    return original != null &&
        hasChanges(original, rating: _rating, comment: _comment.text);
  }

  @override
  void initState() {
    super.initState();
    _scope.addListener(_onScopeChanged);
    final product = _product;
    _loading = product != null;
    if (product != null) _fetch(product.barcode, _generation);
  }

  @override
  void didUpdateWidget(EditReviewFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.context.product?.barcode != _product?.barcode) _load();
  }

  @override
  void dispose() {
    _scope.removeListener(_onScopeChanged);
    _comment.dispose();
    super.dispose();
  }

  /// Outro módulo gravou (ex.: T07): recarrega, sem descartar edição em curso.
  void _onScopeChanged() {
    if (!_saving && !_dirty) _load();
  }

  Future<void> _load() async {
    final product = _product;
    final generation = ++_generation;
    if (product == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _fetch(product.barcode, generation);
  }

  Future<void> _fetch(String barcode, int generation) async {
    try {
      final review = findMyReview(await _scope.reviews.mine(), barcode);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _fill(review);
      });
    } on AppFailure catch (e) {
      _failLoad(e.message, generation);
    } on FeaturePending catch (e) {
      _failLoad('$e', generation);
    } on Exception {
      _failLoad(
        'Não foi possível carregar sua avaliação. Tente novamente.',
        generation,
      );
    }
  }

  void _failLoad(String message, int generation) {
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _loadError = message;
    });
  }

  void _fill(Review? review) {
    _original = review;
    _rating = review?.rating;
    _comment.text = review?.comment ?? '';
    _ratingError = null;
    _commentError = null;
    _saveError = null;
  }

  void _discard() => setState(() => _fill(_original));

  Future<void> _save() async {
    final product = _product;
    final original = _original;
    if (product == null || original == null || _saving || !_dirty) return;
    setState(() {
      _ratingError = validateRating(_rating);
      _commentError = validateComment(_comment.text);
      _saveError = null;
    });
    if (_ratingError != null || _commentError != null) return;
    final draft = buildDraft(
      barcode: product.barcode,
      rating: _rating,
      comment: _comment.text,
    );
    setState(() => _saving = true);
    try {
      // Upsert por (barcode, user_id): altera a avaliação existente.
      await _scope.reviews.save(draft);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _original = Review(
          id: original.id,
          barcode: original.barcode,
          userId: original.userId,
          nickname: original.nickname,
          rating: draft.rating,
          comment: draft.comment,
          createdAt: original.createdAt,
        );
        _comment.text = draft.comment;
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Avaliação atualizada.')));
      _scope.refresh();
    } on AppFailure catch (e) {
      _failSave(e.message);
    } on FeaturePending catch (e) {
      _failSave('$e');
    }
  }

  void _failSave(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = message;
    });
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Editar minha avaliação',
    description: 'Altere a nota ou o comentário que você já publicou.',
    child: _body(context),
  );

  Widget _body(BuildContext context) {
    if (_product == null) {
      return const NaEmpty(
        title: 'Nenhum produto selecionado',
        message: 'Abra um produto pelo Catálogo para editar sua avaliação.',
        icon: Icons.edit_note,
      );
    }
    if (_loading) return const NaLoading(label: 'Carregando sua avaliação…');
    if (_loadError != null) {
      return NaError(message: _loadError!, onRetry: _load);
    }
    final original = _original;
    if (original == null) {
      return const NaEmpty(
        title: 'Você ainda não avaliou este produto',
        message:
            'Publique uma avaliação em "Sua avaliação" para poder editá-la.',
        icon: Icons.rate_review_outlined,
      );
    }
    final saveError = _saveError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Avaliada em ${formatReviewDate(original.createdAt)}'),
            const SizedBox(height: NaSpace.sm),
            _StarPicker(
              value: _rating,
              enabled: !_saving,
              onChanged: (value) => setState(() {
                _rating = value;
                _ratingError = null;
              }),
            ),
            if (_ratingError != null)
              Text(
                _ratingError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: NaSpace.lg),
            TextFormField(
              controller: _comment,
              enabled: !_saving,
              maxLength: maxCommentLength,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Comentário (opcional)',
                errorText: _commentError,
              ),
              onChanged: (_) => setState(() => _commentError = null),
            ),
            const SizedBox(height: NaSpace.lg),
            NaButton(
              label: 'Salvar alterações',
              loading: _saving,
              onPressed: _dirty ? _save : null,
            ),
            const SizedBox(height: NaSpace.sm),
            OutlinedButton(
              onPressed: _dirty && !_saving ? _discard : null,
              child: const Text('Descartar alterações'),
            ),
            if (saveError != null)
              NaError(
                message: 'Alteração não salva: $saveError',
                onRetry: _save,
              ),
          ],
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final int? value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    label: value == null ? 'Nenhuma nota escolhida' : 'Nota $value de 5',
    child: Wrap(
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            tooltip: star == 1
                ? 'Editar para 1 estrela'
                : 'Editar para $star estrelas',
            iconSize: 32,
            color: NaColors.amber,
            onPressed: enabled ? () => onChanged(star) : null,
            icon: Icon(
              (value ?? 0) >= star
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
          ),
      ],
    ),
  );
}
