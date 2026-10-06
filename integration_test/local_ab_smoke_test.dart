// QUA01 — smoke A/B com os repositórios reais contra o Supabase LOCAL.
// Fica fora de test/: `flutter test` não usa banco real. Roteiro em docs/LOCAL.md.
//
//   flutter test integration_test --dart-define-from-file=config/local.android.json
//
// Recusa qualquer URL que não seja local, então não escreve no projeto da turma.
// Só lê fixtures; a única escrita (avaliação de A) é apagada no fim.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:na_lata/core/app_config.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/list_repository.dart';
import 'package:na_lata/data/supabase_community.dart';
import 'package:na_lata/data/supabase_products.dart';
import 'package:na_lata/data/supabase_reviews.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fixtures de supabase/seeds/.
const userA = 'aaaaaaaa-0000-4000-8000-00000000000a';
const userB = 'bbbbbbbb-0000-4000-8000-00000000000b';
const reviewedProduct = '2000000000011';
const emptyProduct = '2000000000059';
const privateListOfA = 'f0000000-0000-4000-8000-0000000000a1';
const publicListOfA = 'f0000000-0000-4000-8000-0000000000a2';

Future<BackendClient> signIn(AppConfig config, String email) async {
  final client = BackendClient(
    SupabaseClient(
      config.url,
      config.key,
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
  await client.request(
    (db) =>
        db.auth.signInWithPassword(email: email, password: 'nalata-local-123'),
  );
  return client;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late BackendClient a, b;

  setUpAll(() async {
    final config = AppConfig.fromEnvironment();
    config.validate();
    if (config.isDemo || !config.isLocal) {
      throw StateError(
        'Use --dart-define-from-file=config/local.json (ou local.android.json). '
        'Este teste só roda contra o Supabase local.',
      );
    }
    a = await signIn(config, 'aluno.a@nalata.local');
    b = await signIn(config, 'aluno.b@nalata.local');
  });

  test('sessões A e B são contas distintas', () {
    expect(a.requireUserId, userA);
    expect(b.requireUserId, userB);
  });

  test('A lê catálogo e avaliações das fixtures', () async {
    final products = await SupabaseProducts(
      a,
    ).search(const ProductQuery(text: 'Teste'));
    expect(products.map((p) => p.barcode), contains(reviewedProduct));
    expect(products, hasLength(5));

    final reviews = await SupabaseReviews(a).forProduct(reviewedProduct);
    expect(reviews.map((r) => r.nickname).toSet(), {'Aluno A', 'Aluno B'});
    expect(await SupabaseReviews(a).forProduct(emptyProduct), isEmpty);
  });

  test('A grava avaliação, B lê mas não altera nem exclui', () async {
    final reviewsA = SupabaseReviews(a), reviewsB = SupabaseReviews(b);
    await reviewsA.save(
      const ReviewDraft(barcode: emptyProduct, rating: 4, comment: 'smoke A'),
    );
    final created = (await reviewsA.mine()).singleWhere(
      (r) => r.barcode == emptyProduct,
    );
    addTearDown(() => reviewsA.delete(created.id));

    final seenByB = await reviewsB.forProduct(emptyProduct);
    expect(seenByB.single.userId, userA);

    await expectLater(reviewsB.delete(created.id), throwsA(isA<AppFailure>()));
    final updatedByB = await b.request(
      (db) => db
          .from('reviews')
          .update({'comment': 'invadido'})
          .eq('id', created.id)
          .select('id'),
    );
    expect(updatedByB, isEmpty, reason: 'RLS deve afetar zero linhas');

    final after = await reviewsA.forProduct(emptyProduct);
    expect(after.single.comment, 'smoke A');
  });

  test('favoritos e denúncias ficam visíveis só para o dono', () async {
    expect(await SupabaseCommunity(a).favorites(), {reviewedProduct});
    expect(await SupabaseCommunity(b).favorites(), {'2000000000035'});

    final reportsSeenByA = await a.request(
      (db) => db.from('reports').select('id'),
    );
    expect(reportsSeenByA, isEmpty, reason: 'denúncia é de B');
    final reportsSeenByB = await b.request(
      (db) => db.from('reports').select('id'),
    );
    expect(reportsSeenByB, hasLength(1));
  });

  test('B vê só a lista pública de A e não adiciona itens nela', () async {
    final listsB = SupabaseListRepository(b);
    expect(await listsB.byId(privateListOfA), isNull);
    expect((await listsB.byId(publicListOfA))?.ownerId, userA);
    await expectLater(
      listsB.addItem(publicListOfA, emptyProduct),
      throwsA(isA<AppFailure>()),
    );
    // Só o conteúdo: a ordem dos itens é responsabilidade do LIS01.
    expect(await SupabaseListRepository(a).items(publicListOfA), {
      reviewedProduct,
      '2000000000028',
    });
  });
}
