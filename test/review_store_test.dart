import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/clients/backend_client.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/data/supabase_reviews.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/review_store/review_store_feature.dart';

Matcher failure(FailureKind kind) =>
    isA<AppFailure>().having((e) => e.kind, 'kind', kind);

const sessionUserId = '11111111-1111-1111-1111-111111111111';

/// SupabaseClient sem rede: todas as requisições passam pelo [handler].
SupabaseClient mockSupabase(
  Future<http.Response> Function(http.Request request) handler,
) {
  final sdk = SupabaseClient(
    'https://example.supabase.co',
    'public-test-key',
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    httpClient: MockClient(handler),
  );
  addTearDown(sdk.dispose);
  return sdk;
}

/// Sessão local (token sem expiração) para requireUserId sem chamar o auth.
Future<void> signIn(SupabaseClient sdk) => sdk.auth.recoverSession(
  jsonEncode({
    'access_token': 'token-de-teste',
    'token_type': 'bearer',
    'user': {'id': sessionUserId, 'aud': 'authenticated'},
  }),
);

http.Response json(Object body, http.Request request, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );

Map<String, dynamic> row({
  String id = 'r1',
  Object? profiles = const {'nickname': 'Ana'},
}) => {
  'id': id,
  'barcode': '7891000100103',
  'user_id': sessionUserId,
  'rating': 5,
  'comment': 'Ótimo',
  'created_at': '2026-09-28T12:00:00+00:00',
  'profiles': profiles,
};

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  group('validateReviewDraft', () {
    test('aceita nota 1–5 e normaliza comentário', () {
      final valid = validateReviewDraft(
        const ReviewDraft(barcode: ' 123 ', rating: 5, comment: '  bom  '),
      );
      expect(valid.barcode, '123');
      expect(valid.comment, 'bom');
      expect(
        validateReviewDraft(
          ReviewDraft(barcode: '1', rating: 1, comment: 'a' * 500),
        ).comment.length,
        500,
      );
    });
    test('rejeita nota fora de 1–5, comentário longo e produto vazio', () {
      for (final draft in [
        const ReviewDraft(barcode: '1', rating: 0),
        const ReviewDraft(barcode: '1', rating: 6),
        ReviewDraft(barcode: '1', rating: 3, comment: 'a' * 501),
        const ReviewDraft(barcode: '  ', rating: 3),
      ]) {
        expect(
          () => validateReviewDraft(draft),
          throwsA(failure(FailureKind.validation)),
        );
      }
    });
    test('conta caracteres como o banco (emoji vale 1)', () {
      final comment = '😀' * 500; // 1000 unidades UTF-16, 500 caracteres
      expect(
        validateReviewDraft(
          ReviewDraft(barcode: '1', rating: 2, comment: comment),
        ).comment,
        comment,
      );
    });
  });

  group('reviewFromRow', () {
    test('lê apelido pela relação profiles', () {
      final review = reviewFromRow(row());
      expect(review.nickname, 'Ana');
      expect(review.userId, sessionUserId);
      expect(review.rating, 5);
      expect(review.createdAt, DateTime.utc(2026, 9, 28, 12));
    });
    test('usa apelido padrão quando o perfil não vem', () {
      expect(reviewFromRow(row(profiles: null)).nickname, 'Colega');
    });
    test('resposta malformada vira invalidResponse, não lista vazia', () {
      expect(
        () => reviewFromRow({...row(), 'rating': '5'}),
        throwsA(failure(FailureKind.invalidResponse)),
      );
    });
  });

  group('DemoReviews', () {
    test('save faz upsert por produto e usuário da sessão', () async {
      final reviews = DemoReviews();
      await reviews.save(
        const ReviewDraft(barcode: 'demo-leite-1', rating: 3, comment: 'ok'),
      );
      final first = (await reviews.forProduct(
        'demo-leite-1',
      )).firstWhere((r) => r.userId == DemoReviews.userId);
      await reviews.save(
        const ReviewDraft(barcode: 'demo-leite-1', rating: 5, comment: 'bom'),
      );
      final list = await reviews.forProduct('demo-leite-1');
      expect(list, hasLength(2)); // colega + minha, sem duplicar
      final mine = list.singleWhere((r) => r.userId == DemoReviews.userId);
      expect(mine.id, first.id);
      expect(mine.rating, 5);
      expect(mine.comment, 'bom');
      expect(
        (await reviews.mine()).map((r) => r.barcode),
        containsAll(['demo-leite-1', 'demo-chocolate-1']),
      );
    });
    test('rejeita inválido sem gravar', () async {
      final reviews = DemoReviews();
      await expectLater(
        reviews.save(const ReviewDraft(barcode: 'demo-batata-1', rating: 0)),
        throwsA(failure(FailureKind.validation)),
      );
      expect(await reviews.forProduct('demo-batata-1'), isEmpty);
    });
  });

  group('SupabaseReviews', () {
    test('forProduct filtra por barcode e embute profiles', () async {
      late Uri url;
      final sdk = mockSupabase((request) async {
        url = request.url;
        return json([row()], request);
      });
      final list = await SupabaseReviews(
        BackendClient(sdk),
      ).forProduct('7891000100103');
      expect(url.path, '/rest/v1/reviews');
      expect(url.queryParameters['barcode'], 'eq.7891000100103');
      expect(url.queryParameters['select'], contains('profiles(nickname)'));
      expect(url.queryParameters['order'], startsWith('created_at.desc'));
      expect(list.single.nickname, 'Ana');
    });
    test('mine usa o usuário da sessão', () async {
      late Uri url;
      final sdk = mockSupabase((request) async {
        url = request.url;
        return json(<Object>[], request);
      });
      await signIn(sdk);
      expect(await SupabaseReviews(BackendClient(sdk)).mine(), isEmpty);
      expect(url.queryParameters['user_id'], 'eq.$sessionUserId');
    });
    test('save envia upsert com user_id da sessão e sem id', () async {
      late http.Request sent;
      final sdk = mockSupabase((request) async {
        sent = request;
        return json(
          [
            {'id': 'r1'},
          ],
          request,
          status: 201,
        );
      });
      await signIn(sdk);
      await SupabaseReviews(BackendClient(sdk)).save(
        const ReviewDraft(barcode: '7891000100103', rating: 4, comment: ' x '),
      );
      expect(sent.method, 'POST');
      expect(sent.url.queryParameters['on_conflict'], 'barcode,user_id');
      expect(sent.headers['Prefer'], contains('resolution=merge-duplicates'));
      expect(jsonDecode(sent.body), {
        'barcode': '7891000100103',
        'user_id': sessionUserId,
        'rating': 4,
        'comment': 'x',
      });
    });
    test('save sem linha retornada não é sucesso', () async {
      final sdk = mockSupabase((request) async => json(<Object>[], request));
      await signIn(sdk);
      await expectLater(
        SupabaseReviews(
          BackendClient(sdk),
        ).save(const ReviewDraft(barcode: '12345678', rating: 3)),
        throwsA(failure(FailureKind.unavailable)),
      );
    });
    test('save inválido ou sem sessão não chega ao banco', () async {
      var calls = 0;
      final sdk = mockSupabase((request) async {
        calls++;
        return json(<Object>[], request);
      });
      final repo = SupabaseReviews(BackendClient(sdk));
      await expectLater(
        repo.save(const ReviewDraft(barcode: '12345678', rating: 3)),
        throwsA(failure(FailureKind.unauthorized)),
      );
      await signIn(sdk);
      await expectLater(
        repo.save(const ReviewDraft(barcode: '12345678', rating: 9)),
        throwsA(failure(FailureKind.validation)),
      );
      expect(calls, 0);
    });
    test('erro de permissão do banco é padronizado', () async {
      final sdk = mockSupabase(
        (request) async => json(
          {'code': '42501', 'message': 'detalhe privado'},
          request,
          status: 403,
        ),
      );
      await expectLater(
        SupabaseReviews(BackendClient(sdk)).forProduct('12345678'),
        throwsA(failure(FailureKind.unauthorized)),
      );
    });
  });

  group('ReviewStoreFeature', () {
    Future<AppScope> pump(
      WidgetTester tester,
      ReviewRepository reviews, {
      Product? product,
    }) async {
      final scope = AppScope(
        products: DemoProducts(),
        reviews: reviews,
        community: DemoCommunity(),
        openFoodFacts: HttpOpenFoodFactsRepository(),
        isDemo: true,
        userId: DemoReviews.userId,
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: NaTheme.light,
          home: Scaffold(
            body: ListView(
              children: [
                ReviewStoreFeature(
                  context: FeatureContext(
                    scope: scope,
                    product: product,
                    openProduct: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return scope;
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    testWidgets('sem produto orienta e consulta fica vazia', (tester) async {
      await pump(tester, DemoReviews());
      expect(find.textContaining('Nenhum produto aberto'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'demo-batata-1');
      await tapText(tester, 'Avaliações do produto');
      expect(find.text('Nenhuma avaliação'), findsOneWidget);
    });

    testWidgets('rejeita sem nota e salva com nota válida', (tester) async {
      final reviews = DemoReviews();
      await pump(tester, reviews, product: demoProducts.first);
      await tapText(tester, 'Salvar avaliação');
      expect(find.text('Erro: Escolha uma nota de 1 a 5.'), findsOneWidget);
      expect((await reviews.forProduct('demo-leite-1')), hasLength(1));

      await tapText(tester, '5');
      await tester.enterText(find.byType(TextField).last, 'Muito bom');
      await tapText(tester, 'Salvar avaliação');
      expect(find.text('Avaliação salva.'), findsOneWidget);
      expect(find.text('Você (demo) · nota 5 de 5'), findsOneWidget);
      expect(find.textContaining('2 resultado(s)'), findsOneWidget);
    });

    testWidgets('cabe em 320px com texto 200%', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, DemoReviews());
      await tapText(tester, 'Minhas avaliações');
      expect(tester.takeException(), isNull);
    });

    testWidgets('erro do repositório aparece com opção de repetir', (
      tester,
    ) async {
      await pump(tester, _FailingReviews());
      await tapText(tester, 'Minhas avaliações');
      expect(find.text('Não foi possível carregar'), findsOneWidget);
      expect(find.text('Sem conexão. Verifique sua internet.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });
}

class _FailingReviews implements ReviewRepository {
  static const _error = AppFailure(
    FailureKind.network,
    'Sem conexão. Verifique sua internet.',
  );
  @override
  Future<List<Review>> forProduct(String barcode) async => throw _error;
  @override
  Future<List<Review>> mine() async => throw _error;
  @override
  Future<void> save(ReviewDraft draft) async => throw _error;
  @override
  Future<void> delete(String reviewId) async => throw _error;
}
