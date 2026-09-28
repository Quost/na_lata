import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

enum DeleteLoadStatus { loading, ready, failed }

/// Regras da exclusão, sem Flutter/Supabase.
class DeleteReviewController extends ChangeNotifier {
  DeleteReviewController({
    required this.loadMine,
    required this.delete,
    required this.refresh,
    required this.productName,
    this.barcode,
  });

  final Future> Function() loadMine;
  final Future Function(String reviewId) delete;
  final VoidCallback refresh;
  final Future Function(String barcode) productName;

  /// Produto aberto; null na Oficina (lista todas as minhas avaliações).
  final String? barcode;

  DeleteLoadStatus status = DeleteLoadStatus.loading;
  List items = const [];
  Map names = const {};
  String? loadError;
  String? deleteError;
  String? deletingId;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future load() async {
    status = DeleteLoadStatus.loading;
    loadError = null;
    _notify();
    try {
      final mine = await loadMine();
      final own = barcode == null
          ? mine
          : mine.where((r) => r.barcode == barcode).toList();
      final found = {};
      for (final code in own.map((r) => r.barcode).toSet()) {
        try {
          final name = await productName(code);
          if (name != null) found[code] = name;
        } catch (_) {
          // Nome é só apoio visual; o código do produto serve de alternativa.
        }
      }
      items = own;
      names = found;
      status = DeleteLoadStatus.ready;
    } catch (e) {
      loadError = _message(e, 'Não foi possível carregar suas avaliações.');
      status = DeleteLoadStatus.failed;
    }
    _notify();
  }

  /// Chamado só depois de o usuário confirmar.
  Future confirmDelete(Review review) async {
    if (deletingId != null) return false;
    deletingId = review.id;
    deleteError = null;
    _notify();
    try {
      await delete(review.id);
    } catch (e) {
      deletingId = null;
      deleteError = _message(e, 'Não foi possível excluir a avaliação.');
      _notify();
      return false;
    }
    items = items.where((r) => r.id != review.id).toList();
    deletingId = null;
    _notify();
    try {
      refresh();
    } catch (_) {
      // Exclusão concluída.
    }
    return true;
  }

  static String _message(Object e, String fallback) =>
      e is AppFailure ? e.message : fallback;
}

/// Ponto de entrada da Oficina/registro de rotas.
class DeleteReviewFeature extends StatefulWidget {
  const DeleteReviewFeature({super.key, required this.featureContext});
  final FeatureContext featureContext;

  @override
  State createState() => _DeleteReviewFeatureState();
}

class _DeleteReviewFeatureState extends State {
  late final DeleteReviewController _controller;

  @override
  void initState() {
    super.initState();
    final scope = widget.featureContext.scope;
    final product = widget.featureContext.product;
    _controller = DeleteReviewController(
      loadMine: scope.reviews.mine,
      delete: scope.reviews.delete,
      refresh: scope.refresh,
      barcode: product?.barcode,
      productName: (code) async => product?.barcode == code
          ? product!.name
          : (await scope.products.byBarcode(code))?.name,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeleteReviewView(
        controller: _controller,
        scoped: widget.featureContext.product != null,
      );
}

class DeleteReviewView extends StatelessWidget {
  const DeleteReviewView({
    super.key,
    required this.controller,
    this.scoped = false,
  });

  final DeleteReviewController controller;
  final bool scoped;

  Future _ask(BuildContext context, Review review) async {
    final confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir avaliação?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await controller.confirmDelete(review);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avaliação excluída.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          switch (controller.status) {
            case DeleteLoadStatus.loading:
              return const NaLoading(label: 'Carregando suas avaliações');
            case DeleteLoadStatus.failed:
              return NaError(
                message: controller.loadError ?? 'Tente novamente.',
                onRetry: controller.load,
              );
            case DeleteLoadStatus.ready:
              break;
          }
          if (controller.items.isEmpty) {
            return NaEmpty(
              title: 'Nenhuma avaliação para excluir',
              message: scoped
                  ? 'Você ainda não avaliou este produto.'
                  : 'Você ainda não fez nenhuma avaliação.',
            );
          }
          final theme = Theme.of(context).textTheme;
          return NaContent(
            child: ListView(
              padding: NaSpace.page,
              children: [
                NaSection(
                  title: 'Excluir minha avaliação',
                  description: 'Só suas avaliações aparecem aqui.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (controller.deleteError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: NaSpace.md),
                          child: Semantics(
                            liveRegion: true,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: NaColors.red,
                                ),
                                const SizedBox(width: NaSpace.sm),
                                Expanded(
                                  child: Text(
                                    controller.deleteError!,
                                    style: const TextStyle(color: NaColors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (final r in controller.items)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(NaSpace.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.names[r.barcode] ?? r.barcode,
                                  style: theme.titleMedium,
                                ),
                                const SizedBox(height: NaSpace.xs),
                                Semantics(
                                  label: 'Sua nota: ${r.rating} de 5',
                                  child: ExcludeSemantics(
                                    child: Text(
                                      'Nota ${r.rating}/5',
                                      style: theme.bodyLarge?.copyWith(
                                        color: NaColors.amber,
                                      ),
                                    ),
                                  ),
                                ),
                                if (r.comment.isNotEmpty) ...[
                                  const SizedBox(height: NaSpace.sm),
                                  Text(r.comment, style: theme.bodyMedium),
                                ],
                                const SizedBox(height: NaSpace.md),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: NaButton(
                                    label: 'Excluir',
                                    loading: controller.deletingId == r.id,
                                    onPressed: controller.deletingId != null
                                        ? null
                                        : () => _ask(context, r),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}