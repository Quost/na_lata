import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class SightingsFeature extends StatelessWidget {
  const SightingsFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) =>
      const FeaturePlaceholder(task: 'T22', title: 'Registrar onde encontrei');
}
