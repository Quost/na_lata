import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class ReviewFormFeature extends StatelessWidget {
  const ReviewFormFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T07',
    title: 'Criar formulário de avaliação',
  );
}
