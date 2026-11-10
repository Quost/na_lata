import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../core/product_source.dart';
import '../../core/ui_format.dart';
import '../../design_system/na_lata_ui.dart';
import 'link_opener.dart';
import 'product_quality.dart';

/// T06 — Ficha completa do produto.
///
/// Exibe nome, marca, categoria e imagem do [Product] recebido via
/// [FeatureContext.product]. Quando o produto é nulo (abertura pela Oficina),
/// mostra orientação para abrir pelo catálogo.
///
/// CAT04: indica de forma específica o que falta na ficha (foto, marca,
/// quantidade) e, havendo [sourceUrl] do Open Food Facts, oferece abrir a
/// página de edição da fonte. Nada é enviado nem editado pelo app.
class DetailFeature extends StatelessWidget {
  const DetailFeature({
    super.key,
    required this.context,
    this.sourceUrl,
    this.openLink = openExternalLink,
  });
  final FeatureContext context;

  /// URL da fonte do produto (CAT01). Nula para produto manual ou antigo.
  final String? sourceUrl;
  final LinkOpener openLink;

  @override
  Widget build(BuildContext buildContext) {
    final product = context.product;
    if (product == null) {
      return const NaEmpty(
        title: 'Nenhum produto selecionado',
        message: 'Abra um produto pelo catálogo para ver a ficha.',
        icon: Icons.info_outline,
      );
    }
    return _ProductCard(
      product: product,
      sourceUrl: sourceUrl,
      openLink: openLink,
    );
  }
}

/// Ficha visual do produto com imagem, nome, marca, categoria e barcode.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.sourceUrl,
    required this.openLink,
  });
  final Product product;
  final String? sourceUrl;
  final LinkOpener openLink;

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

                // --- Tamanho da embalagem ---
                _InfoRow(
                  icon: Icons.straighten_outlined,
                  label: 'Tamanho',
                  value: product.packageSize?.label ?? 'Não informado',
                ),
                if (product.packageSize != null) ...[
                  const SizedBox(height: NaSpace.sm),
                  _InfoRow(
                    icon: Icons.source_outlined,
                    label: 'Origem do tamanho',
                    value: _sizeSourceLabel(product.packageSize!.source),
                  ),
                ],

                const SizedBox(height: NaSpace.sm),

                // --- Barcode ---
                _InfoRow(
                  icon: Icons.qr_code,
                  label: 'Código',
                  value: product.barcode,
                ),

                // --- Qualidade da ficha ---
                _QualitySection(
                  product: product,
                  sourceUrl: sourceUrl,
                  openLink: openLink,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Indica campos essenciais ausentes e, quando possível, encaminha a correção
/// para a página de edição do Open Food Facts. Produto de demonstração não é
/// avaliado: é fictício e não tem fonte.
class _QualitySection extends StatefulWidget {
  const _QualitySection({
    required this.product,
    required this.sourceUrl,
    required this.openLink,
  });
  final Product product;
  final String? sourceUrl;
  final LinkOpener openLink;

  @override
  State<_QualitySection> createState() => _QualitySectionState();
}

class _QualitySectionState extends State<_QualitySection> {
  bool _opening = false;
  bool _failed = false;

  Future<void> _open(Uri uri) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await widget.openLink(uri);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    if (product.isDemo) return const SizedBox.shrink();
    final missing = missingEssentialFields(product);
    if (missing.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: NaSpace.lg),
        child: NaNotice(
          icon: Icons.check_circle_outline,
          message: 'Ficha completa: foto, marca e quantidade informadas.',
        ),
      );
    }
    final uri = offEditUri(
      barcode: product.barcode,
      sourceUrl: widget.sourceUrl,
    );
    return Padding(
      padding: const EdgeInsets.only(top: NaSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NaNotice(
            icon: Icons.warning_amber_outlined,
            message:
                'Ficha incompleta. Faltam: '
                '${missing.map((field) => field.label).join(', ')}.',
          ),
          const SizedBox(height: NaSpace.sm),
          if (uri != null) ...[
            NaButton(
              label: 'Corrigir no Open Food Facts',
              loading: _opening,
              onPressed: () => _open(uri),
            ),
            const SizedBox(height: NaSpace.sm),
            Text(
              'Abre a página de edição no navegador. O app não envia seus '
              'dados nem altera a ficha.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            const NaNotice(
              icon: Icons.link_off,
              message:
                  'Correção indisponível: este produto não tem fonte Open '
                  'Food Facts registrada (cadastro manual ou ficha antiga).',
            ),
          if (_failed) ...[
            const SizedBox(height: NaSpace.sm),
            const NaNotice(
              icon: Icons.error_outline,
              message:
                  'Não foi possível abrir o link. Tente novamente mais tarde.',
            ),
          ],
        ],
      ),
    );
  }
}

String _sizeSourceLabel(PackageSizeSource source) => switch (source) {
  PackageSizeSource.offStructured => 'Open Food Facts (campo estruturado)',
  PackageSizeSource.offText => 'Open Food Facts (texto da embalagem)',
};

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
          if (product.cachedAt != null) ...[
            const SizedBox(height: NaSpace.md),
            Container(
              padding: const EdgeInsets.all(NaSpace.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(NaSpace.sm),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.offline_bolt_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: NaSpace.sm),
                  Expanded(
                    child: Text(
                      'Dados salvos offline em ${formatShortDate(product.cachedAt!)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
