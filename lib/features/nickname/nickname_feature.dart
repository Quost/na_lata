import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class NicknameFeature extends StatelessWidget {
  const NicknameFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) =>
      const FeaturePlaceholder(task: 'T23', title: 'Definir apelido');
}
