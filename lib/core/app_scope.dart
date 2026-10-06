import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import '../data/demo_repositories.dart' show DemoBrands;
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
    BrandRepository? brands,
    AuthRepository? auth,
  }) : brands = brands ?? DemoBrands(products),
       auth = auth ?? DemoAuthRepository();
  final ProductRepository products;
  final ReviewRepository reviews;
  final CommunityRepository community;
  final OpenFoodFactsRepository openFoodFacts;

  /// Sem injeção explícita, as marcas são derivadas de [products].
  final BrandRepository brands;

  /// Mesma instância do SessionController; sem injeção, modo demonstração.
  final AuthRepository auth;
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
