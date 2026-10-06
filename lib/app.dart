import 'dart:async';

import 'package:flutter/material.dart';
import 'core/app_scope.dart';
import 'core/models.dart';
import 'feature_registry.dart';
import 'features/catalog/catalog_no_results.dart';
import 'features/appearance/theme_controller.dart';
import 'features/history/history_feature.dart' show recordVisit;
import 'design_system/na_lata_ui.dart';

class NaLataApp extends StatelessWidget {
  const NaLataApp({super.key, required this.scope});
  final AppScope scope;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeController,
    builder: (context, mode, _) => MaterialApp(
      title: 'Na Lata',
      debugShowCheckedModeBanner: false,
      theme: NaTheme.light,
      darkTheme: NaTheme.dark,
      themeMode: mode,
      home: HomePage(scope: scope),
    ),
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
    unawaited(recordVisit(p, userId: widget.scope.userId));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductPage(scope: widget.scope, product: p),
      ),
    );
  }

  FeatureContext get featureContext =>
      FeatureContext(scope: widget.scope, openProduct: openProduct);

  Widget _feature(String task) =>
      features.firstWhere((t) => t.$1 == task).$3(featureContext);

  static const _tabs = [
    (Icons.storefront_outlined, 'Catálogo'),
    (Icons.explore_outlined, 'Explorar'),
    (Icons.person_outline, 'Meu canto'),
  ];

  /// Ações de "adicionar/encontrar um produto" agrupadas fora da rolagem do
  /// catálogo, para a lista de produtos respirar. Abre em um bottom sheet.
  void _openAddProduct() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: NaSpace.page,
          children: [
            Text(
              'Adicionar um produto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: NaSpace.xs),
            Text(
              'Escaneie o código de barras, digite o código ou busque no '
              'Open Food Facts para trazer o produto ao catálogo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: NaSpace.lg),
            _feature('T03'), // Ler código de barras pela câmera
            _feature('T04'), // Consultar código digitado
            _feature('T01'), // Consultar no Open Food Facts
            _feature('T02'), // Importar produto
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.scope,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Na Lata'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NaSpace.md),
            child: Chip(
              label: Text(widget.scope.isDemo ? 'DEMONSTRAÇÃO' : 'ONLINE'),
            ),
          ),
        ],
      ),
      body: switch (tab) {
        0 => _CatalogTab(
          scope: widget.scope,
          featureContext: featureContext,
          onOpenProduct: openProduct,
        ),
        1 => _ExploreTab(feature: _feature),
        _ => _MyCornerTab(feature: _feature),
      },
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddProduct,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          for (final (icon, label) in _tabs)
            NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    ),
  );
}

/// Aba Catálogo: a lista de produtos é o conteúdo principal. Busca e filtros
/// ficam logo acima; as ações de adicionar produto vão no botão flutuante.
class _CatalogTab extends StatelessWidget {
  const _CatalogTab({
    required this.scope,
    required this.featureContext,
    required this.onOpenProduct,
  });
  final AppScope scope;
  final FeatureContext featureContext;
  final void Function(Product) onOpenProduct;

  Widget _feature(String task) =>
      features.firstWhere((t) => t.$1 == task).$3(featureContext);

  @override
  Widget build(BuildContext context) => ListView(
    padding: NaSpace.page,
    children: [
      Text(
        'Comprou. Provou. Falou.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: NaSpace.xs),
      Text(
        scope.isDemo
            ? 'Você está no modo demonstração, com produtos de exemplo para explorar o app.'
            : 'Avaliações de alimentos feitas pela comunidade.',
      ),
      const SizedBox(height: NaSpace.lg),
      _feature('T05'), // busca por nome
      _feature('T12'), // filtros (recolhível)
      const SizedBox(height: NaSpace.md),
      FutureBuilder<List<Product>>(
        future: scope.products.search(scope.query),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorPanel(error: snapshot.error, retry: scope.refresh);
          }
          if (!snapshot.hasData) {
            return const NaLoading(label: 'Carregando produtos…');
          }
          if (snapshot.data!.isEmpty) {
            return CatalogNoResults(scope: scope);
          }
          return Column(
            children: [
              for (final p in snapshot.data!)
                NaItemCard(
                  title: p.name,
                  subtitle:
                      '${p.brand ?? "Marca não informada"} • '
                      '${p.category ?? "Sem categoria"}',
                  leading: const Icon(Icons.inventory_2_outlined),
                  onTap: () => onOpenProduct(p),
                ),
              // Espaço para o FAB não cobrir o último card.
              const SizedBox(height: 72),
            ],
          );
        },
      ),
    ],
  );
}

/// Aba Explorar: curadoria e descoberta por qualidade.
class _ExploreTab extends StatelessWidget {
  const _ExploreTab({required this.feature});
  final Widget Function(String) feature;

  @override
  Widget build(BuildContext context) => ListView(
    padding: NaSpace.page,
    children: [
      Text('Explorar', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: NaSpace.xs),
      Text(
        'Descubra os melhores avaliados, compare produtos e navegue por '
        'marca e categoria.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: NaSpace.lg),
      feature('T14'), // ranking por categoria
      feature('T13'), // marcas
      feature('T21'), // nota mínima (filtro de descoberta)
      feature('T20'), // comparar dois produtos
    ],
  );
}

/// Aba Meu canto: o que é do usuário.
class _MyCornerTab extends StatelessWidget {
  const _MyCornerTab({required this.feature});
  final Widget Function(String) feature;

  @override
  Widget build(BuildContext context) => ListView(
    padding: NaSpace.page,
    children: [
      Text('Meu canto', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: NaSpace.xs),
      Text(
        'Suas avaliações, favoritos e preferências.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: NaSpace.lg),
      feature('AUT02'), // salvar minha conta
      feature('T11'), // minhas avaliações
      feature('T18'), // favoritos
      feature('T24'), // histórico
      feature('T23'), // apelido
      feature('T26'), // aparência (tema)
    ],
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
        openProduct: (p) {
          unawaited(recordVisit(p, userId: scope.userId));
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProductPage(scope: scope, product: p),
            ),
          );
        },
      );
      Widget feature(String task) =>
          features.firstWhere((t) => t.$1 == task).$3(args);

      return Scaffold(
        appBar: AppBar(title: Text(product.name)),
        body: ListView(
          padding: NaSpace.page,
          children: [
            if (product.isDemo)
              const Padding(
                padding: EdgeInsets.only(bottom: NaSpace.md),
                child: NaNotice(
                  icon: Icons.info_outline,
                  message:
                      'Produto de demonstração. Em modo online, ele não é '
                      'importado para o catálogo real.',
                ),
              ),
            // Sobre o produto
            feature('T06'), // ficha (imagem, marca, categoria, código)
            feature('T18'), // favoritar (ação rápida junto da ficha)
            const SizedBox(height: NaSpace.lg),
            // Como a turma avaliou
            feature('T10'), // resumo (média + histograma)
            feature('T09'), // comentários (com moderação aplicada)
            feature('T19'), // denunciar comentário
            const SizedBox(height: NaSpace.lg),
            // Sua opinião
            feature('T07'), // formulário de avaliação
            feature('T16'), // editar minha avaliação
            const SizedBox(height: NaSpace.lg),
            // Onde encontrei
            feature('T22'), // relatos de loja/cidade
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
