import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/my_reviews/my_reviews_feature.dart';

Review _review(String id, String barcode, int rating, DateTime at) => Review(
  id: id,
  barcode: barcode,
  userId: 'me',
  nickname: 'Eu',
  rating: rating,
  comment: 'Comentário $id',
  createdAt: at,
);

class FakeReviews implements ReviewRepository {
  List<Review> items = [];
  Object? error;
  Completer<void>? gate;
  int mineCalls = 0;
  @override
  Future<List<Review>> mine() async {
    mineCalls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return [...items];
  }

  @override
  Future<List<Review>> forProduct(String barcode) =>
      throw UnimplementedError('T11 não deve usar lista global');
  @override
  Future<void> save(ReviewDraft draft) => throw UnimplementedError();
  @override
  Future<void> delete(String reviewId) => throw UnimplementedError();
}

class FakeProducts implements ProductRepository {
  FakeProducts(this.items);
  final Map<String, Product> items;
  final lookups = <String>[];
  Object? error;
  @override
  Future<Product?> byBarcode(String barcode) async {
    lookups.add(barcode);
    if (error != null) throw error!;
    return items[barcode];
  }

  @override
  Future<List<Product>> search(ProductQuery query) =>
      throw UnimplementedError('T11 não deve usar busca do catálogo');
  @override
  Future<void> importProduct(Product product) => throw UnimplementedError();
}

const leite = Product(barcode: '7891000100103', name: 'Leite integral');
const cafe = Product(barcode: '7896005800010', name: 'Café torrado');

void main() {
  group('loadMyReviews', () {
    test('usa mine, resolve cada barcode uma vez e ordena por data', () async {
      final reviews = FakeReviews()
        ..items = [
          _review('a', leite.barcode, 4, DateTime.utc(2026, 9, 1)),
          _review('b', cafe.barcode, 5, DateTime.utc(2026, 9, 20)),
          _review('c', leite.barcode, 3, DateTime.utc(2026, 9, 10)),
        ];
      final products = FakeProducts({leite.barcode: leite, cafe.barcode: cafe});
      final entries = await loadMyReviews(reviews, products);
      expect(entries.map((e) => e.review.id), ['b', 'c', 'a']);
      expect(entries.first.product, same(cafe));
      expect(products.lookups..sort(), [cafe.barcode, leite.barcode]..sort());
    });

    test(
      'produto ausente do catálogo fica null sem descartar a avaliação',
      () async {
        final reviews = FakeReviews()
          ..items = [_review('a', '00000000', 2, DateTime.utc(2026))];
        final entries = await loadMyReviews(reviews, FakeProducts({}));
        expect(entries.single.product, isNull);
      },
    );

    test('lista vazia não consulta produtos', () async {
      final products = FakeProducts({});
      expect(await loadMyReviews(FakeReviews(), products), isEmpty);
      expect(products.lookups, isEmpty);
    });

    test('erro do repositório é propagado, não vira lista vazia', () async {
      final reviews = FakeReviews()
        ..error = const AppFailure(FailureKind.timeout, 'Tempo esgotado.');
      await expectLater(
        loadMyReviews(reviews, FakeProducts({})),
        throwsA(isA<AppFailure>()),
      );
      final ok = FakeReviews()
        ..items = [_review('a', leite.barcode, 4, DateTime.utc(2026))];
      final broken = FakeProducts({})
        ..error = const AppFailure(FailureKind.network, 'Sem conexão.');
      await expectLater(loadMyReviews(ok, broken), throwsA(isA<AppFailure>()));
    });

    test('mensagem de erro é segura para a UI', () {
      expect(
        myReviewsErrorMessage(
          const AppFailure(FailureKind.unauthorized, 'Sem permissão.'),
        ),
        'Sem permissão.',
      );
      expect(
        myReviewsErrorMessage(Exception('token=abc payload')),
        'Não foi possível carregar suas avaliações.',
      );
    });
  });

  group('MyReviewsFeature', () {
    late FakeReviews reviews;
    late FakeProducts products;
    late AppScope scope;
    late List<Product> opened;

    setUp(() {
      reviews = FakeReviews();
      products = FakeProducts({leite.barcode: leite});
      opened = [];
      scope = AppScope(
        products: products,
        reviews: reviews,
        community: DemoCommunity(),
        openFoodFacts: HttpOpenFoodFactsRepository(),
        isDemo: true,
        userId: 'me',
      );
    });
    tearDown(() => scope.dispose());

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MyReviewsFeature(
              context: FeatureContext(scope: scope, openProduct: opened.add),
            ),
          ),
        ),
      ),
    );

    testWidgets('mostra loading e depois abre produto pelo barcode', (
      tester,
    ) async {
      reviews
        ..gate = Completer<void>()
        ..items = [_review('a', leite.barcode, 4, DateTime.utc(2026, 9, 1))];
      await pump(tester);
      expect(find.text('Carregando suas avaliações…'), findsOneWidget);
      reviews.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);
      expect(find.textContaining('Nota 4 de 5'), findsOneWidget);
      await tester.tap(find.text('Leite integral'));
      expect(opened.single.barcode, leite.barcode);
    });

    testWidgets('estado vazio', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Você ainda não avaliou nada'), findsOneWidget);
    });

    testWidgets('erro com mensagem segura e nova tentativa', (tester) async {
      reviews.error = const AppFailure(FailureKind.network, 'Sem conexão.');
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão.'), findsOneWidget);
      reviews
        ..error = null
        ..items = [_review('a', leite.barcode, 5, DateTime.utc(2026))];
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);
    });

    testWidgets('produto fora do catálogo não é clicável', (tester) async {
      reviews.items = [_review('x', '12345678', 3, DateTime.utc(2026))];
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Produto 12345678'), findsOneWidget);
      expect(find.textContaining('não encontrado no catálogo'), findsOneWidget);
      await tester.tap(find.text('Produto 12345678'));
      expect(opened, isEmpty);
    });

    testWidgets('recarrega depois de scope.refresh()', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Você ainda não avaliou nada'), findsOneWidget);
      reviews.items = [_review('a', leite.barcode, 4, DateTime.utc(2026))];
      scope.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsOneWidget);
      expect(reviews.mineCalls, 2);
    });
  });

  test('modo demo mostra somente as avaliações do usuário demo', () async {
    final entries = await loadMyReviews(DemoReviews(), DemoProducts());
    expect(entries.map((e) => e.review.userId).toSet(), {'demo-user'});
    expect(entries.single.product?.name, 'Chocolate ao leite');
  });
}
