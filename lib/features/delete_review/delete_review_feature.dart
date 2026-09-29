import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class DeleteReviewFeature extends StatelessWidget {
  const DeleteReviewFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) =>
      const FeaturePlaceholder(task: 'T17', title: 'Excluir minha avaliação');
}
