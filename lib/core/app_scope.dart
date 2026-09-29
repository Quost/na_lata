import 'package:flutter/material.dart';

import 'contracts.dart';
import 'models.dart';

class AppScope extends ChangeNotifier {
  AppScope({
    required this.products,
    required this.reviews,
    required this.community,
    required this.openFoodFacts,
    required this.isDemo,
    required this.userId,
  });
  final ProductRepository products;
  final ReviewRepository reviews;
  final CommunityRepository community;
  final OpenFoodFactsRepository openFoodFacts;
  final bool isDemo;
  final String userId;
  ProductQuery query = const ProductQuery();
  final Set<String> comparison = {};
  void refresh() => notifyListeners();
  void setQuery(ProductQuery value) {
    query = value;
    notifyListeners();
  }
}

class FeatureContext {
  const FeatureContext({
    required this.scope,
    required this.openProduct,
    this.product,
  });
  final AppScope scope;
  final Product? product;
  final void Function(Product) openProduct;
}

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.task,
    required this.title,
  });
  final String task, title;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.construction_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title\nEntrega $task — implemente este módulo',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}
