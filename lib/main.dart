import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_scope.dart';
import 'core/app_config.dart';
import 'data/auth_repository.dart';
import 'data/demo_repositories.dart';
import 'data/open_food_facts_repository.dart';
import 'data/supabase_products.dart';
import 'data/supabase_reviews.dart';
import 'data/supabase_community.dart';
import 'data/clients/backend_client.dart';
import 'features/appearance/theme_controller.dart';
import 'features/auth/session_controller.dart';
import 'features/auth/session_gate.dart';

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
      client = BackendClient(Supabase.instance.client);
    }
    final products = demo ? DemoProducts() : SupabaseProducts(client!);
    final reviews = demo ? DemoReviews() : SupabaseReviews(client!);
    final community = demo ? DemoCommunity() : SupabaseCommunity(client!);
    final openFoodFacts = HttpOpenFoodFactsRepository();
    // A sessão (anônima ou conta) é controlada pelo SessionController; o
    // escopo é recriado a cada troca de usuário.
    final session = SessionController(
      demo ? DemoAuthRepository() : SupabaseAuthRepository(client!),
    );
    unawaited(session.start());
    runApp(
      SessionGate(
        controller: session,
        scopeFor: (userId) => AppScope(
          products: products,
          reviews: reviews,
          community: community,
          openFoodFacts: openFoodFacts,
          isDemo: demo,
          userId: userId,
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
