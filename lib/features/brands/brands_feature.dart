// Base de agregação inspirada no ranking de Leonardo Volpi (T13/T14).
import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

/// Marca com seus produtos e a nota geral agregada.
class BrandStat {
  const BrandStat({
    required this.brand,
    required this.products,
    required this.average,
    required this.totalReviews,
  });

  final String brand;
  final List<Product> products;

  /// Média ponderada de TODAS as avaliações da marca; null quando não há nota.
  final double? average;
  final int totalReviews;
}

/// Nota da marca por MÉDIA PONDERADA: soma de todas as notas de todos os
/// produtos da marca dividida pelo total de avaliações — NÃO a média das
/// médias. Produtos sem marca ficam de fora. A lista é ordenada por média
/// (desc; marcas sem nota por último), depois total (desc) e nome (asc).
List<BrandStat> buildBrandStats({
  required List<Product> products,
  required Map<String, List<Review>> reviewsByBarcode,
}) {
  final byBrand = <String, List<Product>>{};
  for (final product in products) {
    final brand = product.brand?.trim();
    if (brand == null || brand.isEmpty) continue; // sem marca não entra
    byBrand.putIfAbsent(brand, () => <Product>[]).add(product);
  }

  final stats = <BrandStat>[];
  byBrand.forEach((brand, brandProducts) {
    var sum = 0;
    var total = 0;
    for (final product in brandProducts) {
      final reviews = reviewsByBarcode[product.barcode] ?? const <Review>[];
      for (final review in reviews) {
        if (review.rating < 1 || review.rating > 5) continue;
        sum += review.rating;
        total++;
      }
    }
    final sorted = [...brandProducts]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    stats.add(
      BrandStat(
        brand: brand,
        products: sorted,
        average: total == 0 ? null : sum / total,
        totalReviews: total,
      ),
    );
  });

  stats.sort((a, b) {
    final aAvg = a.average;
    final bAvg = b.average;
    if (aAvg == null && bAvg == null) {
      return a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
    }
    if (aAvg == null) return 1; // marcas sem nota vão para o fim
    if (bAvg == null) return -1;
    final byAverage = bAvg.compareTo(aAvg);
    if (byAverage != 0) return byAverage;
    final byTotal = b.totalReviews.compareTo(a.totalReviews);
    if (byTotal != 0) return byTotal;
    return a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
  });
  return stats;
}

class BrandsFeature extends StatefulWidget {
  const BrandsFeature({super.key, required this.context});

  final FeatureContext context;

  @override
  State<BrandsFeature> createState() => _BrandsFeatureState();
}

class _BrandsFeatureState extends State<BrandsFeature> {
  List<BrandStat>? _brands;
  String? _error;
  String? _selected;
  int _generation = 0;

  AppScope get _scope => widget.context.scope;

  @override
  void initState() {
    super.initState();
    _scope.addListener(_reload);
    _fetch(_generation);
  }

  @override
  void dispose() {
    _scope.removeListener(_reload);
    super.dispose();
  }

  /// Reage a refresh()/setQuery(): recarrega o agregado por marca.
  void _reload() {
    final generation = ++_generation;
    setState(() {
      _brands = null;
      _error = null;
    });
    _fetch(generation);
  }

  Future<void> _fetch(int generation) async {
    try {
      // Escopo global: todo o catálogo, independente da busca.
      final products = await _scope.products.search(const ProductQuery());
      final lists = await Future.wait(
        products.map((p) => _scope.reviews.forProduct(p.barcode)),
      );
      final reviewsByBarcode = <String, List<Review>>{
        for (var i = 0; i < products.length; i++) products[i].barcode: lists[i],
      };
      final brands = buildBrandStats(
        products: products,
        reviewsByBarcode: reviewsByBarcode,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _brands = brands;
        // Mantém a seleção só se a marca ainda existir.
        if (_selected != null && !brands.any((b) => b.brand == _selected)) {
          _selected = null;
        }
      });
    } on AppFailure catch (e) {
      _fail(e.message, generation);
    } on FeaturePending catch (e) {
      _fail('$e', generation);
    } on Exception {
      _fail(
        'Não foi possível carregar as marcas. Tente novamente.',
        generation,
      );
    }
  }

  void _fail(String message, int generation) {
    if (!mounted || generation != _generation) return;
    setState(() => _error = message);
  }

  BrandStat? _find(List<BrandStat> brands, String? name) {
    if (name == null) return null;
    for (final brand in brands) {
      if (brand.brand == name) return brand;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Notas por marca',
    description:
        'Escolha uma marca para ver seus produtos e a nota geral, calculada '
        'sobre todas as avaliações da turma.',
    child: _body(),
  );

  Widget _body() {
    if (_error != null) return NaError(message: _error!, onRetry: _reload);
    final brands = _brands;
    if (brands == null) return const NaLoading(label: 'Carregando marcas…');
    if (brands.isEmpty) {
      return const NaEmpty(
        title: 'Nenhuma marca disponível',
        message: 'Os produtos do catálogo ainda não têm marca informada.',
        icon: Icons.sell_outlined,
      );
    }
    final selected = _find(brands, _selected);
    return selected == null ? _brandList(brands) : _brandDetail(selected);
  }

  Widget _brandList(List<BrandStat> brands) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final stat in brands)
        NaItemCard(
          leading: const Icon(Icons.storefront_outlined, color: NaColors.amber),
          title: stat.brand,
          subtitle: _describeBrand(stat),
          onTap: () => setState(() => _selected = stat.brand),
        ),
    ],
  );

  Widget _brandDetail(BrandStat stat) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _selected = null),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Todas as marcas'),
        ),
      ),
      const SizedBox(height: NaSpace.sm),
      Text(stat.brand, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: NaSpace.xs),
      Text(_describeBrand(stat)),
      const SizedBox(height: NaSpace.md),
      _BrandFollowButton(scope: _scope, brandKey: stat.brand),
      const SizedBox(height: NaSpace.md),
      for (final product in stat.products)
        NaItemCard(
          leading: const Icon(Icons.shopping_bag_outlined),
          title: product.name,
          subtitle: product.category ?? 'Sem categoria',
          onTap: () => widget.context.openProduct(product),
        ),
    ],
  );

  String _describeBrand(BrandStat stat) {
    final products = stat.products.length;
    final productLabel = products == 1 ? 'produto' : 'produtos';
    final average = stat.average;
    if (average == null) {
      return 'Sem avaliações · $products $productLabel';
    }
    final formatted = average.toStringAsFixed(1).replaceAll('.', ',');
    final reviewLabel = stat.totalReviews == 1 ? 'avaliação' : 'avaliações';
    return '$formatted de 5 · ${stat.totalReviews} $reviewLabel · '
        '$products $productLabel';
  }
}

class _BrandFollowButton extends StatefulWidget {
  const _BrandFollowButton({required this.scope, required this.brandKey});

  final AppScope scope;
  final String brandKey;

  @override
  State<_BrandFollowButton> createState() => _BrandFollowButtonState();
}

class _BrandFollowButtonState extends State<_BrandFollowButton> {
  bool? _isFollowing;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (!widget.scope.isAuthenticated) {
      _isFollowing = false;
      _loading = false;
      return;
    }
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final following = await widget.scope.brandFollows.isFollowing(
        widget.brandKey,
      );
      if (!mounted) return;
      setState(() {
        _isFollowing = following;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _errorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollowing() async {
    if (!widget.scope.isAuthenticated) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Salve suas marcas favoritas'),
          content: const Text(
            'Entre ou crie uma conta para seguir marcas e acompanhar novidades.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    final previous = _isFollowing!;
    final next = !previous;
    setState(() {
      _isFollowing = next;
      _saving = true;
    });
    try {
      await widget.scope.brandFollows.setFollowing(
        brandKey: widget.brandKey,
        isFollowing: next,
      );
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFollowing = previous;
        _saving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const NaLoading();
    if (_loadError != null) {
      return NaError(message: _loadError!, onRetry: _loadFollowing);
    }
    return FilledButton.icon(
      onPressed: _saving ? null : _toggleFollowing,
      icon: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _isFollowing!
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_outlined,
            ),
      label: Text(_isFollowing! ? 'Seguindo' : 'Seguir marca'),
    );
  }
}

String _errorMessage(Object error) => error is AppFailure
    ? error.message
    : 'Não foi possível acessar as marcas. Tente novamente.';
