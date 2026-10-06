import 'package:flutter/material.dart';
import '../../design_system/na_lata_ui.dart';
import 'unit_price_logic.dart';

String formatObservationDate(DateTime date) {
  final utc = date.toUtc();
  return '${utc.day.toString().padLeft(2, '0')}/'
      '${utc.month.toString().padLeft(2, '0')}/${utc.year} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')} UTC';
}

class UnitPricePanel extends StatelessWidget {
  const UnitPricePanel({super.key, required this.comparison});
  final UnitPriceComparison comparison;

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Custo por quantidade',
    description:
        '${comparison.window.regionLabel} · '
        'De ${formatObservationDate(comparison.window.from)} '
        'até ${formatObservationDate(comparison.window.until)} (fim exclusivo).',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = comparison.items
                .map((item) => _product(context, item))
                .toList();
            if (constraints.maxWidth < 480 ||
                MediaQuery.textScalerOf(context).scale(16) > 24) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cards[0],
                  const SizedBox(height: NaSpace.md),
                  cards[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: NaSpace.md),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        const SizedBox(height: NaSpace.md),
        Text(
          comparison.verdict,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: NaSpace.sm),
        const Text(
          'Últimos preços relatados na região e no período. '
          'Lojas e datas podem ser diferentes. '
          'Relatos não garantem oferta, preço atual ou estoque. '
          'Compare produtos equivalentes; a menor embalagem nem sempre tem o menor custo.',
        ),
      ],
    ),
  );

  Widget _product(BuildContext context, ProductUnitPrice item) {
    final quantity = item.quantity;
    final observation = item.observation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.product.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: NaSpace.sm),
            Text(
              quantity?.normalized == null
                  ? 'Quantidade desconhecida'
                  : 'Embalagem: ${quantity!.value} ${quantity.unit.name}',
            ),
            Text(item.cost?.formatted ?? 'Custo por quantidade indisponível'),
            if (observation == null)
              const Text('Sem preço válido na região e no período.')
            else ...[
              Text('Embalagem: ${formatCents(BigInt.from(observation.cents))}'),
              Text(
                'Fonte: relato em ${observation.store} · ${observation.cityLabel}',
              ),
              Text(
                'Observado em ${formatObservationDate(observation.observedAt)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
