import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import 'history_store.dart';

export 'history_store.dart' show recordVisit;

/// Código do histórico com o produto encontrado no catálogo (ou null).
class HistoryEntry {
  const HistoryEntry(this.barcode, this.product);
  final String barcode;
  final Product? product;
}

class HistoryFeature extends StatefulWidget {
  const HistoryFeature({super.key, required this.context, this.store});
  final FeatureContext context;
  final HistoryStore? store;
  @override
  State<HistoryFeature> createState() => _HistoryFeatureState();
}

class _HistoryFeatureState extends State<HistoryFeature> {
  late final HistoryStore _store = widget.store ?? HistoryStore();
  List<HistoryEntry> _entries = const [];
  bool _loading = true;
  bool _clearing = false;
  String? _error;
  bool _storageError = false;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    HistoryStore.changes.addListener(_reload);
    _fetch();
  }

  @override
  void dispose() {
    HistoryStore.changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    final loadId = ++_loadId;
    try {
      final codes = await _store.load();
      final products = await Future.wait(
        codes.map(widget.context.scope.products.byBarcode),
      );
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _entries = [
          for (var i = 0; i < codes.length; i++)
            HistoryEntry(codes[i], products[i]),
        ];
        _loading = false;
      });
    } catch (error) {
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _error = _messageFor(error);
        _storageError = error is HistoryException;
        _loading = false;
      });
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Os produtos vistos neste aparelho serão removidos da lista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await _store.clear();
      if (!mounted) return;
      setState(() => _entries = const []);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _showMissing(String barcode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('O produto $barcode não está mais no catálogo.')),
    );
  }

  String _messageFor(Object error) => switch (error) {
    AppFailure(:final message) => message,
    HistoryException(:final message) => message,
    FeaturePending(:final task) =>
      'A busca por código ainda não foi entregue ($task).',
    _ => 'Não foi possível carregar o histórico. Tente novamente.',
  };

  @override
  Widget build(BuildContext context) => NaContent(
    child: NaSection(
      title: 'Vistos recentemente',
      description:
          'Últimos $historyLimit produtos abertos neste aparelho, do mais recente ao mais antigo.',
      child: _buildBody(),
    ),
  );

  Widget _buildBody() {
    if (_loading) return const NaLoading(label: 'Carregando histórico…');
    if (_error != null) {
      final error = NaError(message: _error!, onRetry: _reload);
      if (!_storageError) return error;
      // Dado salvo inválido: tentar de novo não resolve, limpar resolve.
      return Column(children: [error, _clearButton()]);
    }
    if (_entries.isEmpty) {
      return const NaEmpty(
        icon: Icons.history,
        title: 'Nenhum produto visto ainda',
        message: 'Abra um produto no Catálogo e ele aparecerá aqui.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in _entries)
          if (entry.product case final product?)
            NaItemCard(
              title: product.name,
              subtitle:
                  '${product.brand ?? "Marca não informada"} • ${product.barcode}',
              leading: const Icon(Icons.history),
              onTap: () => widget.context.openProduct(product),
            )
          else
            NaItemCard(
              title: 'Produto indisponível',
              subtitle: 'Código ${entry.barcode} • não está mais no catálogo',
              leading: const Icon(Icons.help_outline),
              onTap: () => _showMissing(entry.barcode),
            ),
        const SizedBox(height: NaSpace.md),
        _clearButton(),
      ],
    );
  }

  Widget _clearButton() => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: _clearing ? null : _confirmClear,
      icon: const Icon(Icons.delete_outline),
      label: Text(_clearing ? 'Limpando…' : 'Limpar histórico'),
    ),
  );
}
