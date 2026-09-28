import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class RankingFeature extends StatelessWidget {
  const RankingFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T14',
    title: 'Classificar produtos por categoria',
  );
}
