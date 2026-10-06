import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/app_scope.dart';
import 'core/app_config.dart';
import 'core/navigation/deep_links.dart';
import 'data/demo_repositories.dart';
import 'data/demo_lists.dart';
import 'data/demo_profiles.dart';
import 'data/list_repository.dart';
import 'data/profile_repository.dart';
import 'data/open_food_facts_repository.dart';
import 'data/brand_repository.dart';
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
    final products = demo ? DemoProducts() : SupabaseProducts(client!);
    final lists = demo ? DemoListRepository() : SupabaseListRepository(client!);
    final profiles = demo
        ? DemoProfileRepository()
        : SupabaseProfileRepository(client!);
    runApp(
      NaLataApp(
        scope: AppScope(
          products: products,
          reviews: demo ? DemoReviews() : SupabaseReviews(client!),
          community: demo ? DemoCommunity() : SupabaseCommunity(client!),
          brands: demo ? null : SupabaseBrands(client!),
          openFoodFacts: HttpOpenFoodFactsRepository(),
          isDemo: demo,
          userId: demo ? 'demo-user' : client!.requireUserId,
        ),
        deepLinkResolver: DeepLinkResolver(
          RepositoryDeepLinkContentSource(
            products: products,
            lists: lists,
            profiles: profiles,
          ),
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
