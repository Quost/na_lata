import 'package:flutter/material.dart';

import '../../core/app_scope.dart';

class ImportFeature extends StatelessWidget {
  const ImportFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  Widget build(BuildContext buildContext) => const FeaturePlaceholder(
    task: 'T02',
    title: 'Importar produto no Supabase',
  );
}
