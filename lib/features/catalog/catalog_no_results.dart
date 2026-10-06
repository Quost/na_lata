import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../design_system/na_lata_ui.dart';
import 'catalog_filter_summary.dart';

/// Estado "Nenhum resultado" do catálogo.
///
/// Com filtros ativos, diz qual combinação não encontrou nada e oferece
/// limpá-la. Sem filtros, o catálogo está vazio e a saída é adicionar produto.
class CatalogNoResults extends StatelessWidget {
  const CatalogNoResults({super.key, required this.scope});
  final AppScope scope;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _content(),
      // Espaço para o botão Adicionar não cobrir a ação, como na lista.
      const SizedBox(height: 72),
    ],
  );

  Widget _content() {
    final items = productFilterItems(scope.query);
    if (items.isEmpty) {
      return const NaEmpty(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum produto encontrado',
        message:
            'O catálogo está vazio. Toque em Adicionar para trazer um produto novo.',
      );
    }
    return NaEmpty(
      icon: Icons.search_off,
      title: 'Nenhum produto encontrado',
      message:
          'Nenhum produto combina com ${describeFilters(items)}. '
          'Limpe os filtros para ver todo o catálogo.',
      action: OutlinedButton.icon(
        onPressed: () => scope.setQuery(const ProductQuery()),
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('Limpar filtros'),
      ),
    );
  }
}
