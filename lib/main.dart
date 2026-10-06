import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/app_scope.dart';
import 'core/app_config.dart';
import 'core/contracts.dart';
import 'data/demo_repositories.dart';
import 'data/open_food_facts_repository.dart';
import 'data/brand_repository.dart';
import 'data/product_refresh_repository.dart';
import 'data/supabase_products.dart';
import 'data/supabase_reviews.dart';
import 'data/supabase_community.dart';
import 'data/clients/backend_client.dart';
import 'features/appearance/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();
  try {
    final config = AppConfig.fromEnvironment();
    config.validate();
    final demo = config.isDemo;
    BackendClient? client;
    if (!demo) {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      );
      final sdk = Supabase.instance.client;
      client = BackendClient(sdk);
      if (sdk.auth.currentSession == null) {
        await client.request((db) => db.auth.signInAnonymously());
      }
    }
    final ProductRepository products;
    final ProductRefreshRepository productRefresh;
    if (demo) {
      final memory = DemoProducts();
      products = memory;
      productRefresh = DemoProductRefresh(memory);
    } else {
      products = SupabaseProducts(client!);
      productRefresh = SupabaseProductRefresh(client, products);
    }
    runApp(
      NaLataApp(
        scope: AppScope(
          products: products,
          productRefresh: productRefresh,
          reviews: demo ? DemoReviews() : SupabaseReviews(client!),
          community: demo ? DemoCommunity() : SupabaseCommunity(client!),
          brands: demo ? null : SupabaseBrands(client!),
          openFoodFacts: HttpOpenFoodFactsRepository(),
          isDemo: demo,
          userId: demo ? 'demo-user' : client!.requireUserId,
        ),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível iniciar o Na Lata.\n$error\nConfira a configuração e reinicie o app.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
