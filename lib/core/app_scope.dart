import 'package:flutter/material.dart';
import 'contracts.dart';
import 'models.dart';
import 'notification_contracts.dart';

class AppScope extends ChangeNotifier {
  AppScope({
    required this.products,
    required this.reviews,
    required this.community,
    required this.openFoodFacts,
    required this.isDemo,
    required this.userId,
    this.notificationPreferences,
  });

  final ProductRepository products;
  final ReviewRepository reviews;
  final CommunityRepository community;
  final OpenFoodFactsRepository openFoodFacts;

  final bool isDemo;
  final String userId;

  final NotificationPreferencesRepository? notificationPreferences;

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