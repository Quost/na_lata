import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class BarcodeFeature extends StatelessWidget {
  const BarcodeFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) =>
      const FeaturePlaceholder(task: 'T04', title: 'Consultar código digitado');
}
