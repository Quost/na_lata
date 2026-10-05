import 'package:flutter/material.dart';
import 'contracts.dart';
import 'models.dart';

class AppScope extends ChangeNotifier {
  AppScope({
    required this.products,
    required this.reviews,
    required this.community,
    BrandFollowRepository? brandFollows,
    required this.openFoodFacts,
    required this.isDemo,
    this.isAuthenticated = true,
    required this.userId,
  }) : brandFollows = brandFollows ?? const _PendingBrandFollows();
  final ProductRepository products;
  final ReviewRepository reviews;
  final CommunityRepository community;
  final BrandFollowRepository brandFollows;
  final OpenFoodFactsRepository openFoodFacts;
  final bool isDemo;
  final bool isAuthenticated;
  final String userId;
  ProductQuery query = const ProductQuery();
  final Set<String> comparison = {};
  void refresh() => notifyListeners();
  void setQuery(ProductQuery value) {
    query = value;
    notifyListeners();
  }
}

class _PendingBrandFollows implements BrandFollowRepository {
  const _PendingBrandFollows();

  @override
  Future<bool> isFollowing(String brandKey) async =>
      throw const FeaturePending('MAR03 — seguir marcas');

  @override
  Future<List<String>> followingBrands() async =>
      throw const FeaturePending('MAR03 — seguir marcas');

  @override
  Future<void> setFollowing({
    required String brandKey,
    required bool isFollowing,
  }) async => throw const FeaturePending('MAR03 — seguir marcas');
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
