import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../data/open_food_facts_repository.dart';
import '../../design_system/na_lata_ui.dart';

/// Oficina da T01: consulta um código no Open Food Facts e mostra o resultado.
/// Não importa nem abre a ficha; esse fluxo pertence às T02/T03/T04.
class OffFeature extends StatefulWidget {
  const OffFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<OffFeature> createState() => _OffFeatureState();
}

class _OffFeatureState extends State<OffFeature> {
  final _form = GlobalKey<FormState>();
  final _barcode = TextEditingController();
  bool _loading = false;
  String? _searched, _error;
  Product? _product;

  @override
  void dispose() {
    _barcode.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Digite o código de barras.';
    if (!isOffBarcode(code)) return 'O código deve ter de 8 a 14 dígitos.';
    return null;
  }

  void _submit() {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _lookup(_barcode.text.trim());
  }

  /// Uma consulta por ação do usuário; nova tentativa só pelo botão.
  Future<void> _lookup(String barcode) async {
    setState(() {
      _loading = true;
      _searched = barcode;
      _product = null;
      _error = null;
    });
    try {
      final product = await widget.context.scope.openFoodFacts.lookup(barcode);
      if (mounted) setState(() => _product = product);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Consultar Open Food Facts',
    description:
        'Digite o código de barras para buscar o produto no catálogo público.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _form,
          child: TextFormField(
            controller: _barcode,
            readOnly: _loading,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14),
            ],
            decoration: const InputDecoration(
              labelText: 'Código de barras',
              hintText: 'Ex.: 7891000100103',
              helperText: 'De 8 a 14 dígitos',
            ),
            validator: _validate,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: NaSpace.lg),
        NaButton(label: 'Consultar', loading: _loading, onPressed: _submit),
        const SizedBox(height: NaSpace.lg),
        _result(),
      ],
    ),
  );

  Widget _result() {
    final searched = _searched;
    if (_loading) return const NaLoading(label: 'Consultando Open Food Facts…');
    if (searched == null) return const SizedBox.shrink();
    if (_error != null) {
      return NaError(message: _error!, onRetry: () => _lookup(searched));
    }
    final product = _product;
    if (product == null) {
      return NaEmpty(
        title: 'Produto não encontrado',
        message:
            'O código $searched não está no Open Food Facts. '
            'Confira os números ou tente outro código.',
        icon: Icons.search_off,
      );
    }
    return _OffProductCard(product: product);
  }
}

class _OffProductCard extends StatelessWidget {
  const _OffProductCard({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _OffProductImage(url: product.imageUrl)),
            const SizedBox(height: NaSpace.md),
            Text(product.name, style: text.titleMedium),
            const SizedBox(height: NaSpace.xs),
            Text('Marca: ${product.brand ?? 'não informada'}'),
            Text('Categoria: ${product.category ?? 'não informada'}'),
            Text('Código: ${product.barcode}'),
            const SizedBox(height: NaSpace.md),
            Text(
              'Fonte: Open Food Facts (dados sob licença ODbL)',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto ausente ou que falha ao carregar mostra aviso textual, não só ícone.
class _OffProductImage extends StatelessWidget {
  const _OffProductImage({required this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    const missing = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.no_photography_outlined, size: 40),
        SizedBox(height: NaSpace.xs),
        Text('Sem foto disponível'),
      ],
    );
    final url = this.url;
    if (url == null) return missing;
    return ClipRRect(
      borderRadius: BorderRadius.circular(NaRadius.control),
      child: Image.network(
        url,
        height: 160,
        fit: BoxFit.contain,
        semanticLabel: 'Foto do produto',
        errorBuilder: (_, _, _) => missing,
      ),
    );
  }
}
