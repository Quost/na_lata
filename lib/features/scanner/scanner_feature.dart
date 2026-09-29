import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class ScannerFeature extends StatelessWidget {
  const ScannerFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T03',
    title: 'Ler código de barras pela câmera',
  );
}
