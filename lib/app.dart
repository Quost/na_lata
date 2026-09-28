import 'package:flutter/material.dart';
import 'core/app_scope.dart';
import 'core/models.dart';
import 'feature_registry.dart';
import 'design_system/na_lata_ui.dart';

class NaLataApp extends StatelessWidget {
  const NaLataApp({super.key, required this.scope});
  final AppScope scope;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Na Lata',
    debugShowCheckedModeBanner: false,
    theme: NaTheme.light,
    home: HomePage(scope: scope),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.scope});
  final AppScope scope;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  void openProduct(Product p) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductPage(scope: widget.scope, product: p),
      ),
    );
  }

  FeatureContext get featureContext =>
      FeatureContext(scope: widget.scope, openProduct: openProduct);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.scope,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Na Lata'),
        actions: [
          IconButton(
            tooltip: 'Design system',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DesignSystemGallery(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Chip(
              label: Text(
                widget.scope.isDemo ? 'DEMONSTRAÇÃO' : 'TURMA • ONLINE',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: NaSpace.page,
        children: [
          Text(
            'Comprou. Provou. Falou.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            widget.scope.isDemo
                ? 'Dados fictícios para desenvolver. As entregas da turma começam nos módulos abaixo.'
                : 'Avaliações da turma. Funcionalidades em construção.',
          ),
          const SizedBox(height: 16),
          if (tab == 0) ...[
            features[4].$3(featureContext),
            features[11].$3(featureContext),
            FutureBuilder<List<Product>>(
              future: widget.scope.products.search(widget.scope.query),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorPanel(
                    error: snapshot.error,
                    retry: widget.scope.refresh,
                  );
                }
                if (!snapshot.hasData) {
                  return const NaLoading();
                }
                if (snapshot.data!.isEmpty) {
                  return const NaEmpty(
                    title: 'Nenhum produto encontrado',
                    message: 'Tente outro nome ou limpe os filtros.',
                  );
                }
                return Column(
                  children: snapshot.data!
                      .map(
                        (p) => NaItemCard(
                          title: p.name,
                          subtitle:
                              '${p.brand ?? "Marca não informada"} • ${p.category ?? "Sem categoria"}',
                          onTap: () => openProduct(p),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            features[3].$3(featureContext),
            features[2].$3(featureContext),
          ],
          if (tab == 1) ...[
            features[12].$3(featureContext),
            features[13].$3(featureContext),
            features[19].$3(featureContext),
            features[20].$3(featureContext),
          ],
          if (tab == 2) ...[
            features[22].$3(featureContext),
            features[10].$3(featureContext),
            features[17].$3(featureContext),
            features[23].$3(featureContext),
          ],
          if (tab == 3)
            ...features.map(
              (f) => Card(
                child: ListTile(
                  title: Text('${f.$1} · ${f.$2}'),
                  subtitle: const Text('Abrir módulo de desenvolvimento'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(f.$1)),
                        body: AnimatedBuilder(
                          animation: widget.scope,
                          builder: (context, _) => SingleChildScrollView(
                            padding: NaSpace.page,
                            child: Column(
                              children: [
                                const Text(
                                  'Módulos de produto devem ser abertos pela ficha no Catálogo.',
                                ),
                                f.$3(featureContext),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Meu canto',
          ),
          NavigationDestination(icon: Icon(Icons.code), label: 'Oficina'),
        ],
      ),
    ),
  );
}

class ProductPage extends StatelessWidget {
  const ProductPage({super.key, required this.scope, required this.product});
  final AppScope scope;
  final Product product;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scope,
    builder: (context, _) {
      final args = FeatureContext(
        scope: scope,
        product: product,
        openProduct: (p) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProductPage(scope: scope, product: p),
          ),
        ),
      );
      return Scaffold(
        appBar: AppBar(title: Text(product.name)),
        body: ListView(
          padding: NaSpace.page,
          children: [
            if (product.isDemo)
              const Text('Produto fictício • não importar para o Supabase'),
            for (final index in [5, 9, 6, 8, 15, 16, 18, 21])
              features[index].$3(args),
          ],
        ),
      );
    },
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) =>
      NaError(message: '$error', onRetry: retry);
}
