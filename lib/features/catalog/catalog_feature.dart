import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../design_system/na_lata_ui.dart';

/// T05 · Pesquisar catálogo por nome.
class CatalogFeature extends StatefulWidget {
  const CatalogFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<CatalogFeature> createState() => _CatalogFeatureState();
}

ProductQuery buildSearchQuery(ProductQuery current, String rawText) =>
    ProductQuery(
      text: rawText.trim(),
      brand: current.brand,
      category: current.category,
    );

class _CatalogFeatureState extends State<CatalogFeature> {
  late final TextEditingController _controller;
  late String _applied;

  AppScope get _scope => widget.context.scope;

  @override
  void initState() {
    super.initState();
    _applied = _scope.query.text;
    _controller = TextEditingController(text: _applied);
    _scope.addListener(_syncFromScope);
  }

  @override
  void dispose() {
    _scope.removeListener(_syncFromScope);
    _controller.dispose();
    super.dispose();
  }

  void _syncFromScope() {
    final text = _scope.query.text;
    if (text == _applied) return;
    _applied = text;
    _controller.text = text;
  }

  void _submit([String? _]) {
    final query = buildSearchQuery(_scope.query, _controller.text);
    _applied = query.text;
    _controller.text = query.text;
    _scope.setQuery(query);
  }

  void _clear() {
    _controller.clear();
    _submit();
  }

  @override
  Widget build(BuildContext buildContext) {
    final theme = Theme.of(buildContext);
    return Padding(
      padding: const EdgeInsets.only(bottom: NaSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submit,
                    decoration: InputDecoration(
                      labelText: 'Buscar produto por nome',
                      hintText: 'Ex.: leite',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close),
                              onPressed: _clear,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: NaSpace.sm),
              SizedBox(
                height: NaSize.touch,
                width: NaSize.touch,
                child: IconButton.filled(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _submit,
                ),
              ),
            ],
          ),
          ListenableBuilder(
            listenable: _scope,
            builder: (context, _) {
              final q = _scope.query;
              if (q.text.isEmpty && q.brand == null && q.category == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: NaSpace.sm),
                child: Text(
                  _summary(q),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NaColors.muted,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _summary(ProductQuery q) {
    final parts = <String>[
      if (q.text.isNotEmpty) 'nome “${q.text}”',
      if (q.brand != null) 'marca ${q.brand}',
      if (q.category != null) 'categoria ${q.category}',
    ];
    return 'Filtrando por ${parts.join(' • ')}';
  }
}
