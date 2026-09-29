import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class BrandsFeature extends StatelessWidget {
  const BrandsFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T13',
    title: 'Explorar produtos e notas de marca',
  );
}
