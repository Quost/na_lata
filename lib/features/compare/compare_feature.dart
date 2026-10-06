import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import '../summary/rating_summary.dart';
import 'compare_logic.dart';
import 'unit_price_logic.dart';
import 'unit_price_panel.dart';

class CompareFeature extends StatefulWidget {
  const CompareFeature({
    super.key,
    required this.context,
    this.summarize = summarizeReviews,
    this.unitPrices = const PendingUnitPriceRepository(),
  });
  final FeatureContext context;
  final UnitPriceRepository unitPrices;

  /// Padrão é `summarizeReviews` (T10); testes injetam um fake.
  final ReviewSummarizer summarize;
  @override
  State<CompareFeature> createState() => _CompareFeatureState();
}

class _CompareFeatureState extends State<CompareFeature> {
  List<Product>? _catalog;
  String? _catalogError;
  var _selection = const CompareSelection();
  final _slotErrors = <int, String>{};
  List<ComparedProduct>? _result;
  UnitPriceComparison? _unitResult;
  String? _unitError;
  String? _compareError;
  bool _comparing = false;
  var _request = 0;

  /// Recria os campos para desfazer uma escolha recusada.
  var _resets = 0;

  AppScope get _scope => widget.context.scope;

  @override
  void initState() {
    super.initState();
    final product = widget.context.product;
    _selection = CompareSelection.from([
      ..._scope.comparison,
      if (product != null) product.barcode,
    ]);
    _scope.addListener(_loadCatalog);
    _loadCatalog();
  }

  @override
  void dispose() {
    _scope.removeListener(_loadCatalog);
    super.dispose();
  }

  String _describe(Object error) => switch (error) {
    AppFailure(:final message) => message,
    FeaturePending() => '$error',
    RangeError() => 'Há avaliação com nota fora de 1 a 5.',
    ArgumentError(:final message) => '$message',
    _ => 'Erro inesperado ao carregar a comparação.',
  };

  Future<void> _loadCatalog() async {
    if (_catalogError != null) {
      setState(() {
        _catalogError = null;
        _catalog = null;
      });
    }
    try {
      final items = await _scope.products.search(const ProductQuery());
      if (!mounted) return;
      final known = items.map((p) => p.barcode).toSet();
      setState(() {
        _catalog = items;
        // Descarta seleção de produto que saiu do catálogo.
        _selection = CompareSelection.from(
          _selection.barcodes.where(known.contains),
        );
      });
      _syncScope();
      await _compare();
    } on Exception catch (e) {
      if (mounted) setState(() => _catalogError = _describe(e));
    }
  }

  void _syncScope() => _scope.comparison
    ..clear()
    ..addAll(_selection.barcodes);

  void _pick(int slot, String? barcode) {
    final error = _selection.duplicateError(slot, barcode);
    if (error != null) {
      // Recusa o mesmo produto duas vezes e mantém a escolha anterior.
      setState(() {
        _slotErrors[slot] = error;
        _resets++;
      });
      return;
    }
    setState(() {
      _slotErrors.clear();
      _selection = _selection.pick(slot, barcode);
    });
    _syncScope();
    _compare();
  }

  Product? _product(String? barcode) {
    for (final p in _catalog ?? const <Product>[]) {
      if (p.barcode == barcode) return p;
    }
    return null;
  }

  Future<void> _compare() async {
    final request = ++_request;
    if (!_selection.isComplete) {
      setState(() {
        _result = null;
        _unitResult = null;
        _unitError = null;
        _compareError = null;
        _comparing = false;
      });
      return;
    }
    final products = _selection.barcodes.map(_product).nonNulls.toList();
    setState(() {
      _comparing = true;
      _compareError = null;
      _result = null;
      _unitResult = null;
      _unitError = null;
    });
    try {
      final result = await loadComparison(
        reviews: _scope.reviews,
        products: products,
        summarize: widget.summarize,
      );
      if (!mounted || request != _request) return;
      setState(() => _result = result);
      try {
        final unitResult = await loadUnitPrices(
          repository: widget.unitPrices,
          scope: _scope,
          products: products,
        );
        if (mounted && request == _request) {
          setState(() => _unitResult = unitResult);
        }
      } on Exception catch (e) {
        if (mounted && request == _request) {
          setState(() => _unitError = _describe(e));
        }
      } on ArgumentError catch (e) {
        if (mounted && request == _request) {
          setState(() => _unitError = _describe(e));
        }
      }
    } on Exception catch (e) {
      if (mounted && request == _request) {
        setState(() => _compareError = _describe(e));
      }
    } on ArgumentError catch (e) {
      // Nota inválida (RangeError do T10) não pode virar sucesso.
      if (mounted && request == _request) {
        setState(() => _compareError = _describe(e));
      }
    } finally {
      if (mounted && request == _request) setState(() => _comparing = false);
    }
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Comparar dois produtos',
    description:
        'Compare avaliações e custo por kg ou litro de dois produtos equivalentes.',
    child: _body(context),
  );

  Widget _body(BuildContext context) {
    if (_catalogError != null) {
      return NaError(message: _catalogError!, onRetry: _loadCatalog);
    }
    final catalog = _catalog;
    if (catalog == null) return const NaLoading(label: 'Carregando catálogo…');
    if (catalog.length < maxComparedProducts) {
      return const NaEmpty(
        title: 'Produtos insuficientes',
        message:
            'O catálogo precisa de pelo menos dois produtos para comparar. '
            'Consulte um código de barras para importar produtos.',
        icon: Icons.compare_arrows,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _picker(catalog, 0, 'Primeiro produto', _selection.first),
        const SizedBox(height: NaSpace.md),
        _picker(catalog, 1, 'Segundo produto', _selection.second),
        const SizedBox(height: NaSpace.lg),
        if (!_selection.isComplete)
          const NaEmpty(
            title: 'Selecione dois produtos',
            message:
                'A comparação aparece quando os dois lados forem escolhidos.',
            icon: Icons.compare_arrows,
          )
        else if (_comparing)
          const NaLoading(label: 'Comparando avaliações…')
        else if (_compareError != null)
          NaError(message: _compareError!, onRetry: _compare)
        else if (_result != null) ...[
          _ComparisonTable(items: _result!),
          const SizedBox(height: NaSpace.lg),
          if (_unitError != null)
            NaError(message: _unitError!, onRetry: _compare)
          else if (_unitResult != null)
            UnitPricePanel(comparison: _unitResult!),
        ],
      ],
    );
  }

  Widget _picker(
    List<Product> catalog,
    int slot,
    String label,
    String? value,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('compare-slot-$slot-$value-$_resets'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      errorText: _slotErrors[slot],
      errorMaxLines: 3,
    ),
    items: [
      for (final p in catalog)
        DropdownMenuItem(
          value: p.barcode,
          child: Text(
            p.brand == null ? p.name : '${p.name} · ${p.brand}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (barcode) => _pick(slot, barcode),
  );
}

/// Duas colunas com os mesmos rótulos para leitura direta, sem depender de cor.
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.items});
  final List<ComparedProduct> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(
              context,
              'Produto',
              (c) => Text(c.product.name, style: theme.textTheme.titleMedium),
            ),
            _row(
              context,
              'Marca',
              (c) => Text(c.product.brand ?? 'Marca não informada'),
            ),
            _row(
              context,
              'Média',
              (c) => Text(
                formatAverage(c.summary.average),
                style: theme.textTheme.titleMedium,
              ),
            ),
            _row(
              context,
              'Quantidade',
              (c) => Text(formatCount(c.summary.count)),
            ),
            _row(
              context,
              'Distribuição',
              (c) => _Histogram(summary: c.summary),
            ),
            const Divider(),
            Text(
              compareVerdict(items[0], items[1]),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    Widget Function(ComparedProduct) cell,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: NaSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: NaColors.muted),
        ),
        const SizedBox(height: NaSpace.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cell(items[0])),
            const SizedBox(width: NaSpace.md),
            Expanded(child: cell(items[1])),
          ],
        ),
      ],
    ),
  );
}

class _Histogram extends StatelessWidget {
  const _Histogram({required this.summary});
  final RatingSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (var star = 5; star >= 1; star--) _bar(star)],
  );

  Widget _bar(int star) {
    final count = summary.histogram[star] ?? 0;
    return Semantics(
      label: '$star ${star == 1 ? 'estrela' : 'estrelas'}: $count',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: NaSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$star★: $count'),
              LinearProgressIndicator(
                value: summary.count == 0 ? 0 : count / summary.count,
                color: NaColors.amber,
                backgroundColor: NaColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
