import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class SummaryFeature extends StatelessWidget {
  const SummaryFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T10',
    title: 'Calcular resumo das avaliações',
  );
}
