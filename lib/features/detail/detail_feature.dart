import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';

/// T06 — Ficha completa do produto.
///
/// Exibe nome, marca, categoria e imagem do [Product] recebido via
/// [FeatureContext.product]. Quando o produto é nulo (abertura pela Oficina),
/// mostra orientação para abrir pelo catálogo.
class DetailFeature extends StatelessWidget {
  const DetailFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  Widget build(BuildContext buildContext) {
    final product = context.product;
    if (product == null) {
      return const _EmptyState();
    }
    return _ProductCard(product: product, isDemo: context.scope.isDemo);
  }
}

/// Orientação exibida quando nenhum produto foi selecionado.
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhum produto selecionado.\n'
              'Abra um produto pelo catálogo para ver a ficha.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Ficha visual do produto com imagem, nome, marca, categoria e barcode.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.isDemo});
  final Product product;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Imagem ---
          _ProductImage(imageUrl: product.imageUrl),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Badge demo ---
                if (product.isDemo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                      avatar: const Icon(Icons.science_outlined, size: 16),
                      label: const Text('DEMONSTRAÇÃO'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),

                // --- Nome ---
                Text(product.name, style: theme.textTheme.headlineSmall),

                const SizedBox(height: 12),

                // --- Marca ---
                _InfoRow(
                  icon: Icons.factory_outlined,
                  label: 'Marca',
                  value: product.brand ?? 'Marca não informada',
                ),

                const SizedBox(height: 8),

                // --- Categoria ---
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Categoria',
                  value: product.category ?? 'Sem categoria',
                ),

                const SizedBox(height: 8),

                // --- Barcode ---
                _InfoRow(
                  icon: Icons.qr_code,
                  label: 'Código',
                  value: product.barcode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Exibe a imagem do produto ou um placeholder quando a URL é nula ou falha.
class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder(context);
    }
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (ctx, error, stackTrace) => _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) => Container(
    height: 200,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 48),
          SizedBox(height: 8),
          Text('Imagem indisponível'),
        ],
      ),
    ),
  );
}

/// Linha de informação com ícone, rótulo e valor.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
      const SizedBox(width: 8),
      Text(
        '$label: ',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      Expanded(child: Text(value)),
    ],
  );
}
