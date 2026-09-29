import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class EditReviewFeature extends StatelessWidget {
  const EditReviewFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) =>
      const FeaturePlaceholder(task: 'T16', title: 'Editar minha avaliação');
}
