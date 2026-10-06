import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../core/ui_format.dart';
import '../../data/clients/app_failure.dart';
import '../../data/open_food_facts_repository.dart';
import '../../design_system/na_lata_ui.dart';
import 'product_refresh.dart';

/// CAT02 — atualiza a ficha com os dados da fonte externa.
///
/// A consulta só acontece quando a pessoa pede, mostra o antes/depois e só
/// grava depois da confirmação. Qualquer falha mantém a ficha como estava.
class ProductRefreshPanel extends StatefulWidget {
  const ProductRefreshPanel({
    super.key,
    required this.scope,
    required this.product,
    required this.onUpdated,
  });
  final AppScope scope;
  final Product product;

  /// Recebe a ficha relida depois de uma gravação.
  final void Function(Product product) onUpdated;

  @override
  State<ProductRefreshPanel> createState() => _ProductRefreshPanelState();
}

class _ProductRefreshPanelState extends State<ProductRefreshPanel> {
  bool _checking = false;
  bool _saving = false;
  String? _message;
  CatalogUpdate? _pending;
  List<CatalogChange> _changes = const [];
  int _generation = 0;

  @override
  void didUpdateWidget(ProductRefreshPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.barcode != widget.product.barcode) {
      // Outro produto: descarta consulta em andamento e comparação aberta.
      _generation++;
      _checking = false;
      _saving = false;
      _message = null;
      _pending = null;
      _changes = const [];
    }
  }

  String _keptMessage(Object error) =>
      '${messageForError(error, fallback: 'Não foi possível consultar a fonte.')} '
      'A ficha foi mantida como estava.';

  Future<void> _check() async {
    final generation = ++_generation;
    final current = widget.product;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      // Uma consulta por toque; sem nova tentativa automática.
      final external = await widget.scope.openFoodFacts.lookup(current.barcode);
      if (!mounted || generation != _generation) return;
      if (external == null) {
        setState(() {
          _checking = false;
          _message =
              'A fonte não tem mais este produto. A ficha foi mantida como '
              'estava.';
        });
        return;
      }
      final update = catalogUpdateFrom(current, external);
      final changes = catalogChanges(current, update);
      setState(() {
        _checking = false;
        if (changes.isEmpty) {
          _message = 'A ficha já está atualizada com a fonte.';
        } else {
          _pending = update;
          _changes = changes;
        }
      });
    } on Exception catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _checking = false;
        _message = _keptMessage(error);
      });
    }
  }

  void _cancel() => setState(() {
    _pending = null;
    _changes = const [];
    _message = 'Atualização cancelada. Nada foi alterado.';
  });

  Future<void> _confirm() async {
    final update = _pending;
    final repository = widget.scope.productRefresh;
    if (update == null || repository == null || _saving) return;
    final generation = ++_generation;
    setState(() => _saving = true);
    try {
      final updated = await repository.apply(update);
      if (!mounted || generation != _generation) return;
      setState(() {
        _saving = false;
        _pending = null;
        _changes = const [];
        _message = 'Ficha atualizada com os dados da fonte.';
      });
      widget.onUpdated(updated);
    } on Exception catch (error) {
      Product? reconciled;
      if (error is AppFailure && error.kind == FailureKind.timeout) {
        // Timeout não diz se gravou: relê a ficha em vez de reenviar.
        try {
          reconciled = await widget.scope.products.byBarcode(update.barcode);
        } on Exception {
          reconciled = null;
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _saving = false;
        _pending = null;
        _changes = const [];
        _message = error is AppFailure && error.kind == FailureKind.timeout
            ? error.message
            : _keptMessage(error);
      });
      if (reconciled != null) widget.onUpdated(reconciled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    if (widget.scope.productRefresh == null ||
        product.isDemo ||
        !isOffBarcode(product.barcode)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: NaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: NaSpace.md),
              child: Semantics(
                liveRegion: true,
                child: NaNotice(message: _message!),
              ),
            ),
          if (_pending == null)
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(Icons.sync_outlined),
              label: Text(
                _checking
                    ? 'Consultando a fonte…'
                    : 'Buscar atualização na fonte',
              ),
            )
          else ...[
            Text('O que vai mudar', style: theme.textTheme.titleMedium),
            const SizedBox(height: NaSpace.sm),
            for (final change in _changes)
              Padding(
                padding: const EdgeInsets.only(bottom: NaSpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(change.label, style: theme.textTheme.labelLarge),
                    Text('Antes: ${change.before}'),
                    Text('Depois: ${change.after}'),
                  ],
                ),
              ),
            Text(
              'Avaliações, favoritos e relatos deste produto não são '
              'alterados.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: NaSpace.md),
            NaButton(
              label: 'Confirmar atualização',
              loading: _saving,
              onPressed: _confirm,
            ),
            const SizedBox(height: NaSpace.sm),
            OutlinedButton(
              onPressed: _saving ? null : _cancel,
              child: const Text('Cancelar'),
            ),
          ],
        ],
      ),
    );
  }
}
