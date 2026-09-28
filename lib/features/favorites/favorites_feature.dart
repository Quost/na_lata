import 'package:flutter/material.dart';
import '../../core/app_scope.dart';

class FavoritesFeature extends StatelessWidget {
  const FavoritesFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) =>
      const FeaturePlaceholder(task: 'T18', title: 'Favoritar produtos');
}
