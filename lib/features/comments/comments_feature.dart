import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class CommentsFeature extends StatelessWidget {
  const CommentsFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T09',
    title: 'Exibir comentários do produto',
  );
}
