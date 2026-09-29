// Autoria: Andrey Lazarotto (T19).
import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import '../moderation/comment_moderator.dart';
import 'report_logic.dart';

/// T19 — lista os comentários do produto e permite denunciar cada um.
/// Denunciar não exclui nem esconde o comentário.
class ReportFeature extends StatefulWidget {
  const ReportFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<ReportFeature> createState() => _ReportFeatureState();
}

class _ReportFeatureState extends State<ReportFeature> {
  List<Review> _comments = const [];
  bool _loading = false;
  String? _loadError;
  int _loadToken = 0;
  final Set<String> _reported = {};
  final Set<String> _sending = {};

  AppScope get _scope => widget.context.scope;
  Product? get _product => widget.context.product;

  @override
  void initState() {
    super.initState();
    if (_product != null) _load();
  }

  @override
  void didUpdateWidget(covariant ReportFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.context.product?.barcode;
    final now = _product?.barcode;
    if (before != now) {
      _reported.clear();
      _sending.clear();
      _comments = const [];
      _loadError = null;
      if (now != null) {
        _load();
      } else {
        _loadToken++;
        _loading = false;
      }
    }
  }

  String _messageFor(Object error) =>
      error is AppFailure ? error.message : error.toString();

  Future<void> _load() async {
    final product = _product;
    if (product == null) return;
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final reviews = await _scope.reviews.forProduct(product.barcode);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _comments = reportableComments(reviews);
        _loading = false;
      });
    } on AppFailure catch (error) {
      _failLoad(token, error);
    } on FeaturePending catch (error) {
      _failLoad(token, error);
    } on Exception {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loadError =
            'Não foi possível carregar os comentários. Tente novamente.';
        _loading = false;
      });
    }
  }

  void _failLoad(int token, Object error) {
    if (!mounted || token != _loadToken) return;
    setState(() {
      _loadError = _messageFor(error);
      _loading = false;
    });
  }

  Future<void> _report(Review review) async {
    final reason = await showDialog<ReportReason>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null || !mounted) return;
    setState(() => _sending.add(review.id));
    String message;
    try {
      await _scope.community.report(review.id, reason.value);
      _reported.add(review.id);
      message =
          'Denúncia enviada. O comentário continua visível até a análise.';
    } on AppFailure catch (error) {
      // Duplicidade: o banco já tem a denúncia deste usuário.
      if (error.kind == FailureKind.conflict) _reported.add(review.id);
      message = error.message;
    } on FeaturePending catch (error) {
      message = error.toString();
    } on Exception {
      message = 'Não foi possível enviar a denúncia. Tente novamente.';
    }
    if (!mounted) return;
    setState(() => _sending.remove(review.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    _scope.refresh();
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Denunciar comentário',
    description:
        'Denuncie comentários ofensivos ou spam. A equipe analisa; nada é '
        'removido automaticamente.',
    child: _body(context),
  );

  Widget _body(BuildContext context) {
    if (_product == null) {
      return const NaEmpty(
        title: 'Abra um produto',
        message:
            'Este módulo depende de um produto. Abra a ficha pelo Catálogo '
            'para ver os comentários.',
        icon: Icons.touch_app_outlined,
      );
    }
    if (_loading) return const NaLoading(label: 'Carregando comentários…');
    if (_loadError != null) {
      return NaError(message: _loadError!, onRetry: _load);
    }
    if (_comments.isEmpty) {
      return NaEmpty(
        title: 'Nenhum comentário para denunciar',
        message: 'Este produto ainda não tem comentários.',
        icon: Icons.chat_bubble_outline,
        action: OutlinedButton(
          onPressed: _load,
          child: const Text('Atualizar'),
        ),
      );
    }
    return Column(
      children: [
        for (final review in _comments)
          _CommentCard(
            review: review,
            isOwn: !canReport(review, _scope.userId),
            reported: _reported.contains(review.id),
            sending: _sending.contains(review.id),
            onReport: () => _report(review),
          ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.review,
    required this.isOwn,
    required this.reported,
    required this.sending,
    required this.onReport,
  });
  final Review review;
  final bool isOwn, reported, sending;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: NaSpace.sm,
              runSpacing: NaSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(review.nickname, style: theme.titleMedium),
                Text('Nota ${review.rating} de 5'),
                Text(formatReportDate(review.createdAt)),
              ],
            ),
            const SizedBox(height: NaSpace.sm),
            Text(moderateComment(review.comment)),
            const SizedBox(height: NaSpace.sm),
            _action(),
          ],
        ),
      ),
    );
  }

  Widget _action() {
    if (isOwn) return const Text('Seu comentário');
    if (reported) {
      return const Wrap(
        spacing: NaSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [Icon(Icons.check_circle_outline), Text('Denúncia enviada')],
      );
    }
    return TextButton.icon(
      onPressed: sending ? null : onReport,
      icon: const Icon(Icons.flag_outlined),
      label: Text(sending ? 'Enviando…' : 'Denunciar'),
    );
  }
}

/// Diálogo com escolha obrigatória de motivo. Sem motivo, não confirma.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  ReportReason? _selected;
  bool _showError = false;

  void _confirm() {
    if (_selected == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Qual o motivo da denúncia?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: NaSpace.sm,
            runSpacing: NaSpace.sm,
            children: [
              for (final reason in ReportReason.values)
                ChoiceChip(
                  label: Text(reason.label),
                  selected: _selected == reason,
                  onSelected: (_) => setState(() {
                    _selected = reason;
                    _showError = false;
                  }),
                ),
            ],
          ),
          if (_showError) ...[
            const SizedBox(height: NaSpace.md),
            const Wrap(
              spacing: NaSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.error_outline, color: NaColors.red),
                Text(
                  'Escolha um motivo para denunciar.',
                  style: TextStyle(color: NaColors.red),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('Enviar denúncia')),
    ],
  );
}
