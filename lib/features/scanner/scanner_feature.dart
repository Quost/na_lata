import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import 'scanner_flow.dart';
import 'scanner_page.dart';

class ScannerFeature extends StatefulWidget {
  const ScannerFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<ScannerFeature> createState() => _ScannerFeatureState();
}

class _ScannerFeatureState extends State<ScannerFeature> {
  bool _busy = false;
  String? _message;
  String? _lastCode;

  Future<void> _scan() async {
    final result = await Navigator.of(
      context,
    ).push<ScanResult>(MaterialPageRoute(builder: (_) => const ScannerPage()));
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
      _message = null;
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
        setState(() => _message = 'Produto $code não encontrado.');
        return;
      }
      _lastCode = null;
      widget.context.openProduct(product);
      scope.refresh();
    } on FeaturePending catch (e) {
      if (mounted) setState(() => _message = '$e. Leitura: $code');
    } catch (e) {
      if (mounted) setState(() => _message = 'Falha ao consultar $code: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastCode = _lastCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ler código de barras',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Use a câmera para encontrar ou importar um produto.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _scan,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_scanner),
              label: Text(_busy ? 'Consultando…' : 'Escanear código'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
              if (lastCode != null && !_busy)
                TextButton(
                  onPressed: () => _lookup(lastCode),
                  child: const Text('Tentar novamente'),
                ),
            ],
          ],
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
