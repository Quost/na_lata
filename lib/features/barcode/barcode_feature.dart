import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import 'barcode_lookup.dart';

class BarcodeFeature extends StatefulWidget {
  const BarcodeFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<BarcodeFeature> createState() => _BarcodeFeatureState();
}

class _BarcodeFeatureState extends State<BarcodeFeature> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _notFound;
  Product? _found;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final scope = widget.context.scope;
    final code = normalizeBarcode(_controller.text);
    setState(() {
      _loading = true;
      _error = null;
      _notFound = null;
      _found = null;
    });
    try {
      final result = await BarcodeLookup(
        products: scope.products,
        openFoodFacts: scope.openFoodFacts,
      ).find(code);
      if (!mounted) return;
      switch (result) {
        case BarcodeFound(:final product, :final imported):
          setState(() => _found = product);
          if (imported) scope.refresh();
          widget.context.openProduct(product);
        case BarcodeNotFound(:final barcode):
          setState(() => _notFound = barcode);
      }
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FeaturePending catch (e) {
      if (mounted) setState(() => _error = '$e');
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Erro inesperado ao consultar o código.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Consultar código digitado',
    description:
        'Digite o código de barras da embalagem. Procuramos no catálogo '
        'e, se não houver, no Open Food Facts.',
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _controller,
            enabled: !_loading,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(barcodeMaxLength),
            ],
            decoration: const InputDecoration(
              labelText: 'Código de barras',
              hintText: 'Ex.: 7891000100103',
              helperText: 'De 8 a 14 dígitos',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            validator: validateBarcode,
            onFieldSubmitted: (_) => _search(),
          ),
          const SizedBox(height: NaSpace.lg),
          NaButton(label: 'Consultar', loading: _loading, onPressed: _search),
          if (_loading) const NaLoading(label: 'Consultando código…'),
          if (_error != null) NaError(message: _error!, onRetry: _search),
          if (_notFound != null)
            NaEmpty(
              title: 'Produto não encontrado',
              message:
                  'O código $_notFound não está no catálogo nem no '
                  'Open Food Facts. Confira os dígitos e tente novamente.',
              icon: Icons.search_off,
              action: OutlinedButton(
                onPressed: _search,
                child: const Text('Consultar novamente'),
              ),
            ),
          if (_found != null) ...[
            const SizedBox(height: NaSpace.lg),
            NaItemCard(
              title: _found!.name,
              subtitle: 'Código ${_found!.barcode} • toque para abrir a ficha',
              onTap: () => widget.context.openProduct(_found!),
            ),
          ],
        ],
      ),
    ),
  );
}
