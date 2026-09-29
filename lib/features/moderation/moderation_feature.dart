import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class ModerationFeature extends StatelessWidget {
  const ModerationFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T15',
    title: 'Mascarar palavrões na exibição',
  );
}
