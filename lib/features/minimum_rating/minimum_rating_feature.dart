import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class MinimumRatingFeature extends StatelessWidget {
  const MinimumRatingFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) =>
      const FeaturePlaceholder(task: 'T21', title: 'Filtrar por nota mínima');
}
