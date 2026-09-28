import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class OffFeature extends StatelessWidget {
  const OffFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T01',
    title: 'Consultar produto no Open Food Facts',
  );
}
