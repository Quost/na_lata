import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/app_scope.dart';
import 'data/demo_repositories.dart';
import 'data/open_food_facts_repository.dart';
import 'data/supabase_products.dart';
import 'data/supabase_reviews.dart';
import 'data/supabase_community.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment('APP_MODE', defaultValue: 'demo');
  try {
    if (mode != 'demo' && mode != 'supabase') {
      throw StateError('APP_MODE deve ser demo ou supabase.');
    }
    final demo = mode == 'demo';
    SupabaseClient? client;
    if (!demo) {
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      if (url.isEmpty || key.isEmpty) {
        throw StateError(
          'Configure URL e chave pública em config/classroom.json.',
        );
      }
      await Supabase.initialize(url: url, publishableKey: key);
      client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }
    }
    runApp(
      NaLataApp(
        scope: AppScope(
          products: demo ? DemoProducts() : SupabaseProducts(client!),
          reviews: demo ? DemoReviews() : SupabaseReviews(client!),
          community: demo ? DemoCommunity() : SupabaseCommunity(client!),
          openFoodFacts: HttpOpenFoodFactsRepository(),
          isDemo: demo,
          userId: demo ? 'demo-user' : client!.auth.currentUser!.id,
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
