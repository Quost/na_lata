import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../core/ui_format.dart';
import '../../design_system/na_lata_ui.dart';

class FavoritesFeature extends StatefulWidget {
  const FavoritesFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<FavoritesFeature> createState() => _FavoritesFeatureState();
}

class _FavoritesFeatureState extends State<FavoritesFeature> {
  Set<String> _favoriteBarcodes = {};
  List<Product> _favoriteProducts = [];
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final barcodes = await widget.context.scope.community.favorites();
      final products = widget.context.product == null
          ? await Future.wait(
              barcodes.map(widget.context.scope.products.byBarcode),
            )
          : <Product?>[];
      if (!mounted) return;
      setState(() {
        _favoriteBarcodes = barcodes;
        _favoriteProducts = products.whereType<Product>().toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    final isFavorite = _favoriteBarcodes.contains(product.barcode);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.context.scope.community.setFavorite(
        product.barcode,
        !isFavorite,
      );
      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          _favoriteBarcodes.remove(product.barcode);
        } else {
          _favoriteBarcodes.add(product.barcode);
        }
        _saving = false;
      });
      widget.context.scope.refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.context.product;
    if (product != null) {
      final isFavorite = _favoriteBarcodes.contains(product.barcode);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(NaSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _loading || _saving
                    ? null
                    : () => _toggleFavorite(product),
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                label: Text(
                  isFavorite ? 'Remover dos favoritos' : 'Favoritar produto',
                ),
              ),
              if (_loading || _saving) const LinearProgressIndicator(),
              if (_error != null) ...[
                const SizedBox(height: NaSpace.sm),
                NaError(
                  message: messageForError(
                    _error!,
                    fallback:
                        'Não foi possível acessar os favoritos. Tente novamente.',
                  ),
                  onRetry: _loadFavorites,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_loading) return const NaLoading(label: 'Carregando favoritos…');
    if (_error != null) {
      return NaError(
        message: messageForError(
          _error!,
          fallback: 'Não foi possível acessar os favoritos. Tente novamente.',
        ),
        onRetry: _loadFavorites,
      );
    }
    if (_favoriteProducts.isEmpty && _favoriteBarcodes.isNotEmpty) {
      return NaError(
        message: 'Não foi possível abrir os produtos salvos.',
        onRetry: _loadFavorites,
      );
    }
    if (_favoriteProducts.isEmpty) {
      return const NaEmpty(
        title: 'Você ainda não tem favoritos',
        message: 'Favorite um produto na ficha para encontrá-lo aqui.',
        icon: Icons.favorite_border,
      );
    }
    return NaSection(
      title: 'Favoritos',
      child: Column(
        children: _favoriteProducts
            .map(
              (favorite) => NaItemCard(
                title: favorite.name,
                subtitle:
                    '${favorite.brand ?? "Marca não informada"} • ${favorite.category ?? "Sem categoria"}',
                leading: const Icon(Icons.favorite, color: NaColors.red),
                onTap: () => widget.context.openProduct(favorite),
              ),
            )
            .toList(),
      ),
    );
  }
}
