import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class MyReviewsFeature extends StatelessWidget {
  const MyReviewsFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) =>
      const FeaturePlaceholder(task: 'T11', title: 'Listar minhas avaliações');
}
