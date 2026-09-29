import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class HistoryFeature extends StatelessWidget {
  const HistoryFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T24',
    title: 'Guardar histórico de produtos vistos',
  );
}
