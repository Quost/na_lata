import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scanner_flow.dart';

/// Resultado da tela: um código lido ou pedido de digitação manual.
class ScanResult {
  const ScanResult.code(String this.code);
  const ScanResult.manual() : code = null;
  final String? code;
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _gate = ScanGate();
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = _gate.accept(capture.barcodes.map((b) => b.rawValue));
    if (code == null) return;
    await _controller.stop();
    if (mounted) Navigator.of(context).pop(ScanResult.code(code));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear código')),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _ScannerError(error: error),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Aponte para o código de barras da embalagem.'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});
  final MobileScannerException error;
  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Permissão da câmera negada. Libere nas configurações ou digite o código.',
      MobileScannerErrorCode.unsupported =>
        'Nenhuma câmera disponível neste aparelho.',
      _ => 'Não foi possível abrir a câmera.',
    };
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(const ScanResult.manual()),
                icon: const Icon(Icons.keyboard),
                label: const Text('Digitar código'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
