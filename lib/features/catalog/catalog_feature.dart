import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class CatalogFeature extends StatelessWidget {
  const CatalogFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T05',
    title: 'Pesquisar catálogo por nome',
  );
}
