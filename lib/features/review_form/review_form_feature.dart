import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import 'review_validation.dart';

class ReviewFormFeature extends StatefulWidget {
  const ReviewFormFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<ReviewFormFeature> createState() => _ReviewFormFeatureState();
}

class _ReviewFormFeatureState extends State<ReviewFormFeature> {
  final _comment = TextEditingController();
  int? _rating;
  bool _saving = false;
  String? _ratingError;
  String? _commentError;
  String? _saveError;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final product = widget.context.product;
    if (product == null || _saving) return;
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
      await widget.context.scope.reviews.save(draft);
      if (!mounted) return;
      setState(() {
        _rating = null;
        _comment.clear();
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Avaliação publicada.')));
      widget.context.scope.refresh();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    } on FeaturePending catch (e) {
      if (mounted) setState(() => _saveError = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.context.product == null) {
      return const NaEmpty(
        title: 'Nenhum produto selecionado',
        message: 'Abra um produto pelo Catálogo para avaliá-lo.',
        icon: Icons.rate_review_outlined,
      );
    }
    final saveError = _saveError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: NaSection(
          title: 'Sua avaliação',
          description: 'Dê uma nota de 1 a 5 e, se quiser, comente.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                onChanged: (_) {
                  if (_commentError != null) {
                    setState(() => _commentError = null);
                  }
                },
              ),
              const SizedBox(height: NaSpace.lg),
              NaButton(
                label: 'Publicar avaliação',
                loading: _saving,
                onPressed: _submit,
              ),
              if (saveError != null)
                NaError(
                  message: 'Avaliação não publicada: $saveError',
                  onRetry: _submit,
                ),
            ],
          ),
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
            tooltip: star == 1 ? '1 estrela' : '$star estrelas',
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
