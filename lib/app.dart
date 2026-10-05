import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_scope.dart';
import 'core/navigation/deep_links.dart';
import 'core/models.dart';
import 'feature_registry.dart';
import 'features/appearance/theme_controller.dart';
import 'features/history/history_feature.dart' show recordVisit;
import 'design_system/na_lata_ui.dart';

class NaLataApp extends StatelessWidget {
  const NaLataApp({
    super.key,
    required this.scope,
    this.deepLinkResolver,
    this.deepLinkPlatform = const AndroidDeepLinkPlatform(),
  });
  final AppScope scope;
  final DeepLinkResolver? deepLinkResolver;
  final DeepLinkPlatform deepLinkPlatform;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeController,
    builder: (context, mode, _) => MaterialApp(
      title: 'Na Lata',
      debugShowCheckedModeBanner: false,
      theme: NaTheme.light,
      darkTheme: NaTheme.dark,
      themeMode: mode,
      home: HomePage(
        scope: scope,
        deepLinkResolver:
            deepLinkResolver ??
            DeepLinkResolver(
              RepositoryDeepLinkContentSource(products: scope.products),
            ),
        deepLinkPlatform: deepLinkPlatform,
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.scope,
    required this.deepLinkResolver,
    required this.deepLinkPlatform,
  });
  final AppScope scope;
  final DeepLinkResolver deepLinkResolver;
  final DeepLinkPlatform deepLinkPlatform;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  StreamSubscription<String>? _deepLinkSubscription;
  Future<void> _linkQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _deepLinkSubscription = widget.deepLinkPlatform.links.listen(
      _enqueueDeepLink,
      onError: (Object error) => _enqueueUnavailable(),
    );
    unawaited(_openInitialLink());
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openInitialLink() async {
    try {
      final link = await widget.deepLinkPlatform.initialLink();
      if (link != null) _enqueueDeepLink(link);
    } on PlatformException {
      _enqueueUnavailable();
    }
  }

  void _enqueueDeepLink(String link) {
    _linkQueue = _linkQueue.then((_) => _openDeepLink(link));
  }

  void _enqueueUnavailable() {
    _linkQueue = _linkQueue.then((_) => _showUnavailable());
  }

  Future<void> _openDeepLink(String link) async {
    DeepLinkDestination? destination;
    try {
      destination = await widget.deepLinkResolver.resolve(link);
    } on Exception {
      destination = null;
    }
    if (!mounted) return;
    final page = switch (destination) {
      ProductDestination(:final product) => ProductPage(
        scope: widget.scope,
        product: product,
        deepLinkPlatform: widget.deepLinkPlatform,
      ),
      ProfileDestination(:final profile) => SharedProfilePage(
        profile: profile,
        deepLinkPlatform: widget.deepLinkPlatform,
      ),
      ListDestination(:final sharedList) => SharedListPage(
        sharedList: sharedList,
        deepLinkPlatform: widget.deepLinkPlatform,
      ),
      null => const ContentUnavailablePage(),
    };
    unawaited(
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }

  Future<void> _showUnavailable() async {
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const ContentUnavailablePage()),
      ),
    );
  }

  void openProduct(Product p) {
    unawaited(recordVisit(p, userId: widget.scope.userId));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductPage(
          scope: widget.scope,
          product: p,
          deepLinkPlatform: widget.deepLinkPlatform,
        ),
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
            return const NaEmpty(
              icon: Icons.inventory_2_outlined,
              title: 'Nenhum produto encontrado',
              message:
                  'Tente outro nome, limpe os filtros ou toque em '
                  'Adicionar para trazer um produto novo.',
            );
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
      feature('T11'), // minhas avaliações
      feature('T18'), // favoritos
      feature('T24'), // histórico
      feature('T23'), // apelido
      feature('T26'), // aparência (tema)
    ],
  );
}

class ProductPage extends StatelessWidget {
  const ProductPage({
    super.key,
    required this.scope,
    required this.product,
    this.deepLinkPlatform = const AndroidDeepLinkPlatform(),
  });
  final AppScope scope;
  final Product product;
  final DeepLinkPlatform deepLinkPlatform;
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
              builder: (_) => ProductPage(
                scope: scope,
                product: p,
                deepLinkPlatform: deepLinkPlatform,
              ),
            ),
          );
        },
      );
      Widget feature(String task) =>
          features.firstWhere((t) => t.$1 == task).$3(args);

      return Scaffold(
        appBar: AppBar(
          title: Text(product.name),
          actions: [
            if (RegExp(r'^[0-9]{8,14}$').hasMatch(product.barcode))
              IconButton(
                tooltip: 'Compartilhar produto',
                onPressed: () => _shareLink(
                  context,
                  deepLinkPlatform,
                  DeepLinkRoute.product(product.barcode),
                ),
                icon: const Icon(Icons.share_outlined),
              ),
          ],
        ),
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

class SharedProfilePage extends StatelessWidget {
  const SharedProfilePage({
    super.key,
    required this.profile,
    required this.deepLinkPlatform,
  });

  final SharedProfile profile;
  final DeepLinkPlatform deepLinkPlatform;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Perfil'),
      actions: [
        IconButton(
          tooltip: 'Compartilhar perfil',
          onPressed: () => _shareLink(
            context,
            deepLinkPlatform,
            DeepLinkRoute.profile(profile.id),
          ),
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: NaSpace.page,
      children: [
        Text(
          profile.nickname,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    ),
  );
}

class SharedListPage extends StatelessWidget {
  const SharedListPage({
    super.key,
    required this.sharedList,
    required this.deepLinkPlatform,
  });

  final SharedProductList sharedList;
  final DeepLinkPlatform deepLinkPlatform;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(sharedList.list.name),
      actions: [
        IconButton(
          tooltip: 'Compartilhar lista',
          onPressed: () => _shareLink(
            context,
            deepLinkPlatform,
            DeepLinkRoute.list(sharedList.list.id),
          ),
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: NaSpace.page,
      children: [
        if (sharedList.list.description case final description?)
          Text(description),
        if (sharedList.barcodes.isEmpty)
          const NaEmpty(
            title: 'Lista vazia',
            message: 'Esta lista ainda não tem produtos.',
          )
        else
          for (final barcode in sharedList.barcodes)
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('Código do produto'),
              subtitle: Text(barcode),
            ),
      ],
    ),
  );
}

class ContentUnavailablePage extends StatelessWidget {
  const ContentUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conteúdo indisponível')),
    body: const Center(
      child: Padding(
        padding: NaSpace.page,
        child: NaEmpty(
          icon: Icons.link_off,
          title: 'Não foi possível abrir este link',
          message:
              'O conteúdo pode ter sido removido, ser privado ou o link estar incorreto.',
        ),
      ),
    ),
  );
}

Future<void> _shareLink(
  BuildContext context,
  DeepLinkPlatform platform,
  Uri uri,
) async {
  String? message;
  try {
    await NativeShare(platform).share(uri);
  } on PlatformException {
    message = 'Não foi possível compartilhar este link.';
  } on MissingPluginException {
    message = 'O compartilhamento não está disponível neste dispositivo.';
  }
  if (message != null && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) =>
      NaError(message: '$error', onRetry: retry);
}
