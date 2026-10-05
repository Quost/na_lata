import 'dart:async';

import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';

class FakeProducts implements ProductRepository {
  FakeProducts([List<Product> initial = const []]) : items = [...initial];
  final List<Product> items;
  final List<String> lookups = [];
  final List<Product> imported = [];
  Object? importError;

  @override
  Future<Product?> byBarcode(String barcode) async {
    lookups.add(barcode);
    for (final p in items) {
      if (p.barcode == barcode) return p;
    }
    return null;
  }

  @override
  Future<void> importProduct(Product product) async {
    if (importError != null) throw importError!;
    imported.add(product);
    items.add(product);
  }

  @override
  Future<List<Product>> search(ProductQuery query) async => items;
}

/// OFF sem rede: responde com [response], lança [error] ou espera [pending].
class FakeOpenFoodFacts implements OpenFoodFactsRepository {
  Product? response;
  Object? error;
  Completer<Product?>? pending;
  final List<String> lookups = [];

  @override
  Future<Product?> lookup(String barcode) async {
    lookups.add(barcode);
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return response;
  }
}
