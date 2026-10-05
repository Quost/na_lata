import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

class BrandsFeature extends StatefulWidget {
  const BrandsFeature({super.key, required this.context});

  final FeatureContext context;

  @override
  State<BrandsFeature> createState() => _BrandsFeatureState();
}

class _BrandsFeatureState extends State<BrandsFeature> {
  late Future<List<String>> _brands;

  @override
  void initState() {
    super.initState();
    _brands = _loadBrands();
  }

  Future<List<String>> _loadBrands() async {
    final products = await widget.context.scope.products.search(
      const ProductQuery(),
    );
    final brands =
        products
            .map((product) => product.brand?.trim().toLowerCase())
            .whereType<String>()
            .where((brand) => brand.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return brands;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _brands,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return NaError(
          message: _errorMessage(snapshot.error!),
          onRetry: () => setState(() => _brands = _loadBrands()),
        );
      }
      if (!snapshot.hasData) return const NaLoading();
      if (snapshot.data!.isEmpty) {
        return const NaEmpty(
          title: 'Nenhuma marca no catálogo',
          message: 'As marcas aparecerão quando houver produtos cadastrados.',
        );
      }
      return NaSection(
        title: 'Marcas',
        description: 'Acompanhe as marcas que você quer seguir.',
        child: Column(
          children: [
            for (final brand in snapshot.data!)
              NaItemCard(
                title: brand,
                subtitle: 'Ver marca e seguir',
                leading: const Icon(Icons.sell_outlined),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _BrandDetailsPage(
                      scope: widget.context.scope,
                      brandKey: brand,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _BrandDetailsPage extends StatefulWidget {
  const _BrandDetailsPage({required this.scope, required this.brandKey});

  final AppScope scope;
  final String brandKey;

  @override
  State<_BrandDetailsPage> createState() => _BrandDetailsPageState();
}

class _BrandDetailsPageState extends State<_BrandDetailsPage> {
  bool? _isFollowing;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.brandKey)),
    body: ListView(
      padding: NaSpace.page,
      children: [
        Text(
          widget.brandKey,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: NaSpace.lg),
        if (_loading)
          const NaLoading()
        else if (_loadError != null)
          NaError(message: _loadError!, onRetry: _loadFollowing)
        else
          FilledButton.icon(
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
          ),
      ],
    ),
  );
}

String _errorMessage(Object error) => error is AppFailure
    ? error.message
    : 'Não foi possível acessar as marcas. Tente novamente.';
