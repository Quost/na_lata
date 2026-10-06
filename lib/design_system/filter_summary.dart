import 'package:flutter/material.dart';
import 'tokens.dart';

/// Um filtro ativo mostrado como chip removível.
///
/// O [id] é devolvido em [NaFilterSummary.onRemove]; quem usa o componente
/// decide como remover o filtro de sua própria consulta.
class NaFilterItem {
  const NaFilterItem({
    required this.id,
    required this.dimension,
    required this.value,
  });
  final String id, dimension, value;

  /// Texto do chip, por exemplo "Marca: Fazenda Aurora".
  String get label => '$dimension: $value';

  /// Nome do botão de remover para leitor de tela e tooltip.
  String get removeLabel =>
      'Remover filtro de ${dimension.toLowerCase()}: $value';
}

/// Resumo dos filtros ativos: contagem, chips removíveis e ação Limpar.
///
/// Não conhece a consulta nem remove nada sozinho. Sem itens, não ocupa
/// espaço. Os chips quebram linha e o texto longo é limitado a duas linhas,
/// para caber em 320 px com texto a 200%.
class NaFilterSummary extends StatelessWidget {
  const NaFilterSummary({
    super.key,
    required this.items,
    required this.onRemove,
    required this.onClear,
  });
  final List<NaFilterItem> items;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final count = items.length;
    final headline = count == 1 ? '1 filtro ativo' : '$count filtros ativos';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Anuncia a mudança e lista os filtros de uma vez para leitor de tela.
        Semantics(
          liveRegion: true,
          excludeSemantics: true,
          label: '$headline: ${items.map((item) => item.label).join(', ')}',
          child: Text(
            headline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: NaSpace.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            // Reserva espaço do ícone de remover e do padding do chip.
            final labelMax = constraints.hasBoundedWidth
                ? (constraints.maxWidth - 64).clamp(80.0, double.infinity)
                : double.infinity;
            return Wrap(
              spacing: NaSpace.sm,
              runSpacing: NaSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final item in items)
                  InputChip(
                    label: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: labelMax),
                      child: Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    deleteButtonTooltipMessage: item.removeLabel,
                    onDeleted: () => onRemove(item.id),
                  ),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpar filtros'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
