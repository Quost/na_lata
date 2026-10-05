import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
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
