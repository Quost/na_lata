import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import 'scanner_flow.dart';
import 'scanner_page.dart';

typedef ScannerLauncher = Future<ScanResult?> Function(BuildContext context);

Future<ScanResult?> _openCamera(BuildContext context) => Navigator.of(
  context,
).push<ScanResult>(MaterialPageRoute(builder: (_) => const ScannerPage()));

class ScannerFeature extends StatefulWidget {
  const ScannerFeature({
    super.key,
    required this.context,
    this.openScanner = _openCamera,
  });
  final FeatureContext context;

  /// Abre a câmera; testes injetam uma leitura simulada.
  final ScannerLauncher openScanner;
  @override
  State<ScannerFeature> createState() => _ScannerFeatureState();
}

class _ScannerFeatureState extends State<ScannerFeature> {
  bool _busy = false;
  String? _notFound;
  String? _error;
  String? _lastCode;

  Future<void> _scan() async {
    final result = await widget.openScanner(context);
    if (!mounted || result == null) return;
    final code = result.code ?? await _askCode();
    if (code != null) await _lookup(code);
  }

  Future<String?> _askCode() => showDialog<String>(
    context: context,
    builder: (_) => const _ManualCodeDialog(),
  );

  Future<void> _lookup(String code) async {
    final scope = widget.context.scope;
    setState(() {
      _busy = true;
      _notFound = null;
      _error = null;
      _lastCode = code;
    });
    try {
      final product = await resolveBarcode(
        code,
        products: scope.products,
        openFoodFacts: scope.openFoodFacts,
      );
      if (!mounted) return;
      if (product == null) {
        setState(() => _notFound = code);
        return;
      }
      widget.context.openProduct(product);
      scope.refresh();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FeaturePending catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastCode = _lastCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: NaSection(
          title: 'Ler código de barras',
          description: 'Use a câmera para encontrar ou importar um produto.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NaButton(
                label: 'Escanear código',
                loading: _busy,
                onPressed: _scan,
              ),
              if (_notFound != null)
                NaEmpty(
                  title: 'Produto não encontrado',
                  message:
                      'O código $_notFound não está no catálogo nem no '
                      'Open Food Facts. Confira a embalagem e escaneie de novo.',
                  icon: Icons.search_off,
                ),
              if (_error != null && lastCode != null)
                NaError(
                  message: 'Código $lastCode: $_error',
                  onRetry: () => _lookup(lastCode),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualCodeDialog extends StatefulWidget {
  const _ManualCodeDialog();
  @override
  State<_ManualCodeDialog> createState() => _ManualCodeDialogState();
}

class _ManualCodeDialogState extends State<_ManualCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final code = normalizeBarcode(_controller.text);
    if (code == null) {
      setState(() => _error = 'Informe de 8 a 14 dígitos.');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Digitar código'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      maxLength: 14,
      decoration: InputDecoration(
        labelText: 'Código de barras',
        errorText: _error,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Consultar')),
    ],
  );
}
