import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class ReviewStoreFeature extends StatelessWidget {
  const ReviewStoreFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T08',
    title: 'Persistir e consultar avaliações',
  );
}
