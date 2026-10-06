import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../core/product_source.dart';
import '../../core/ui_format.dart';
import '../../design_system/na_lata_ui.dart';
import 'product_refresh_panel.dart';

/// T06 — Ficha completa do produto.
///
/// Exibe nome, marca, categoria e imagem do [Product] recebido via
/// [FeatureContext.product]. Quando o produto é nulo (abertura pela Oficina),
/// mostra orientação para abrir pelo catálogo.
class DetailFeature extends StatefulWidget {
  const DetailFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<DetailFeature> createState() => _DetailFeatureState();
}

class _DetailFeatureState extends State<DetailFeature> {
  /// Ficha relida depois de atualizar pela fonte (CAT02).
  Product? _refreshed;

  @override
  Widget build(BuildContext buildContext) {
    final opened = widget.context.product;
    if (opened == null) {
      return const NaEmpty(
        title: 'Nenhum produto selecionado',
        message: 'Abra um produto pelo catálogo para ver a ficha.',
        icon: Icons.info_outline,
      );
    }
    final refreshed = _refreshed;
    final product = refreshed != null && refreshed.barcode == opened.barcode
        ? refreshed
        : opened;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProductCard(product: product),
        ProductRefreshPanel(
          scope: widget.context.scope,
          product: product,
          onUpdated: (updated) {
            setState(() => _refreshed = updated);
            // Catálogo e demais telas releem o produto.
            widget.context.scope.refresh();
          },
        ),
      ],
    );
  }
}

/// Ficha visual do produto com imagem, nome, marca, categoria e barcode.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final Product product;

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
            padding: const EdgeInsets.all(NaSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Badge demo ---
                if (product.isDemo)
                  const Padding(
                    padding: EdgeInsets.only(bottom: NaSpace.sm),
                    child: Chip(
                      avatar: Icon(Icons.science_outlined, size: 16),
                      label: Text('DEMONSTRAÇÃO'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),

                // --- Nome ---
                Text(product.name, style: theme.textTheme.headlineSmall),

                const SizedBox(height: NaSpace.md),

                // --- Marca ---
                _InfoRow(
                  icon: Icons.factory_outlined,
                  label: 'Marca',
                  value: product.brand ?? 'Marca não informada',
                ),

                const SizedBox(height: NaSpace.sm),

                // --- Categoria ---
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Categoria',
                  value: product.category ?? 'Sem categoria',
                ),

                const SizedBox(height: NaSpace.sm),

                // --- Barcode ---
                _InfoRow(
                  icon: Icons.qr_code,
                  label: 'Código',
                  value: product.barcode,
                ),

                const SizedBox(height: NaSpace.md),

                // --- Origem dos dados ---
                ProductSourceInfo(product: product),
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
          SizedBox(height: NaSpace.sm),
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
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
      const SizedBox(width: NaSpace.sm),
      Expanded(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Crédito da fonte dos dados, data da consulta e link de origem.
///
/// Produto sem [Product.source] mostra "Origem não informada", sem data nem
/// link. O link só aparece se for HTTPS de host permitido e é oferecido como
/// texto selecionável com botão de copiar (o app não abre links externos).
class ProductSourceInfo extends StatelessWidget {
  const ProductSourceInfo({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOff = product.source == ProductSource.openFoodFacts;
    final fetchedAt = product.sourceFetchedAt;
    final link = safeSourceUri(product.sourceUrl);
    final credit = isOff
        ? 'Dados do Open Food Facts, licença ODbL.'
        : 'Origem não informada';
    return Semantics(
      container: true,
      label: 'Origem dos dados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          _InfoRow(icon: Icons.source_outlined, label: 'Fonte', value: credit),
          if (fetchedAt != null) ...[
            const SizedBox(height: NaSpace.sm),
            _InfoRow(
              icon: Icons.event_outlined,
              label: 'Consultado em',
              value: formatShortDate(fetchedAt),
            ),
          ],
          if (link != null) ...[
            const SizedBox(height: NaSpace.sm),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    link.toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar link da fonte',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: link.toString())),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
