import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class DetailFeature extends StatelessWidget {
  const DetailFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T06',
    title: 'Construir ficha do produto',
  );
}
