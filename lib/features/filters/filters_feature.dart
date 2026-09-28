import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class FiltersFeature extends StatelessWidget {
  const FiltersFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T12',
    title: 'Filtrar por marca e categoria',
  );
}
