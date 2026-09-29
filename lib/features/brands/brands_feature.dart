import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

/// Chave de agrupamento da marca: trim + minúsculas. Nula/vazia = sem marca.
String? brandKey(String? raw) {
  final key = raw?.trim().toLowerCase();
  return key == null || key.isEmpty ? null : key;
}

/// Nota de produto e de marca é sempre um inteiro de 1 a 5.
bool isValidRating(int rating) => rating >= 1 && rating <= 5;

String formatAverage(double average) =>
    average.toStringAsFixed(1).replaceAll('.', ',');

String reviewsLabel(int count) =>
    count == 1 ? '1 avaliação' : '$count avaliações';

String productsLabel(int count) => count == 1 ? '1 produto' : '$count produtos';

String ratingLabel(double? average, int count) => average == null || count == 0
    ? 'Sem avaliações'
    : '${formatAverage(average)} de 5 · ${reviewsLabel(count)}';

class ProductRating {
  const ProductRating({
    required this.product,
    required this.average,
    required this.count,
  });
  final Product product;
  final double? average;
  final int count;
}

class BrandSummary {
  const BrandSummary({
    required this.key,
    required this.name,
    required this.products,
    required this.average,
    required this.count,
  });
  final String key, name;
  final List<ProductRating> products;

  /// Média ponderada: soma de todas as notas ÷ total de avaliações.
  /// Nula quando a marca ainda não tem avaliações.
  final double? average;
  final int count;
}

String _displayName(String raw) {
  final name = raw.trim();
  // brand_key vem em minúsculas do banco; deixar legível na tela.
  if (name != name.toLowerCase()) return name;
  return name
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Agrega as avaliações de TODOS os produtos de cada marca (não faz média
/// das médias). Produtos sem marca ficam fora. Notas fora de 1–5 e produtos
/// repetidos são ignorados.
List<BrandSummary> aggregateBrands(
  List<Product> products,
  Map<String, List<Review>> reviewsByBarcode,
) {
  final names = <String, String>{};
  final byBrand = <String, List<Product>>{};
  final seen = <String>{};
  for (final product in products) {
    final key = brandKey(product.brand);
    if (key == null || !seen.add(product.barcode)) continue;
    names.putIfAbsent(key, () => _displayName(product.brand!));
    byBrand.putIfAbsent(key, () => []).add(product);
  }

  final brands = <BrandSummary>[];
  byBrand.forEach((key, items) {
    var brandSum = 0, brandCount = 0;
    final rated = <ProductRating>[];
    for (final product in items) {
      final ratings = (reviewsByBarcode[product.barcode] ?? const <Review>[])
          .where((r) => r.barcode == product.barcode)
          .map((r) => r.rating)
          .where(isValidRating)
          .toList();
      final sum = ratings.fold<int>(0, (a, b) => a + b);
      brandSum += sum;
      brandCount += ratings.length;
      rated.add(
        ProductRating(
          product: product,
          average: ratings.isEmpty ? null : sum / ratings.length,
          count: ratings.length,
        ),
      );
    }
    rated.sort(
      (a, b) =>
          a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()),
    );
    brands.add(
      BrandSummary(
        key: key,
        name: names[key]!,
        products: rated,
        average: brandCount == 0 ? null : brandSum / brandCount,
        count: brandCount,
      ),
    );
  });
  brands.sort((a, b) => a.key.compareTo(b.key));
  return brands;
}

/// Lê o catálogo importado e as avaliações pelos contratos do AppScope.
/// Falhas dos repositórios são propagadas, nunca viram lista vazia.
Future<List<BrandSummary>> loadBrands(
  ProductRepository products,
  ReviewRepository reviews,
) async {
  final catalog = await products.search(const ProductQuery());
  final branded = catalog.where((p) => brandKey(p.brand) != null).toList();
  final lists = await Future.wait(
    branded.map((p) => reviews.forProduct(p.barcode)),
  );
  return aggregateBrands(catalog, {
    for (var i = 0; i < branded.length; i++) branded[i].barcode: lists[i],
  });
}

String brandsErrorMessage(Object error) {
  if (error is AppFailure) return error.message;
  if (error is FeaturePending) return error.toString();
  return 'Algo deu errado ao montar as marcas. Tente novamente.';
}

class BrandsFeature extends StatefulWidget {
  const BrandsFeature({super.key, required this.context});
  final FeatureContext context;
  @override
  State<BrandsFeature> createState() => _BrandsFeatureState();
}

class _BrandsFeatureState extends State<BrandsFeature> {
  late Future<List<BrandSummary>> _future = _load();
  String? _selectedKey;

  Future<List<BrandSummary>> _load() =>
      loadBrands(widget.context.scope.products, widget.context.scope.reviews);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Explorar marcas',
    description: 'Nota geral calculada com todas as avaliações da marca.',
    child: FutureBuilder<List<BrandSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const NaLoading(label: 'Carregando marcas…');
        }
        if (snapshot.hasError) {
          return NaError(
            message: brandsErrorMessage(snapshot.error!),
            onRetry: _reload,
          );
        }
        final brands = snapshot.data ?? const <BrandSummary>[];
        if (brands.isEmpty) {
          return const NaEmpty(
            title: 'Nenhuma marca no catálogo',
            message:
                'Importe produtos que tenham marca informada para vê-los aqui.',
            icon: Icons.sell_outlined,
          );
        }
        for (final brand in brands) {
          if (brand.key == _selectedKey) return _detail(brand);
        }
        return _list(brands);
      },
    ),
  );

  Widget _list(List<BrandSummary> brands) => Column(
    children: [
      for (final brand in brands)
        NaItemCard(
          title: brand.name,
          subtitle:
              '${productsLabel(brand.products.length)}'
              ' • ${ratingLabel(brand.average, brand.count)}',
          leading: const Icon(Icons.sell_outlined),
          onTap: () => setState(() => _selectedKey = brand.key),
        ),
    ],
  );

  Widget _detail(BrandSummary brand) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _selectedKey = null),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Todas as marcas'),
        ),
      ),
      const SizedBox(height: NaSpace.md),
      Text(brand.name, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: NaSpace.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: NaRatingBadge(average: brand.average, count: brand.count),
      ),
      const SizedBox(height: NaSpace.md),
      for (final item in brand.products)
        NaItemCard(
          title: item.product.name,
          subtitle:
              '${item.product.category ?? 'Sem categoria'}'
              ' • ${ratingLabel(item.average, item.count)}',
          onTap: () => widget.context.openProduct(item.product),
        ),
    ],
  );
}
