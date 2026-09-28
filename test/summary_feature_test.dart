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
import 'package:na_lata/features/summary/summary_feature.dart';

const product = Product(barcode: '7891000100103', name: 'Achocolatado');

var _nextId = 0;
Review review(int rating, {String barcode = '7891000100103'}) => Review(
  id: 'r${_nextId++}',
  barcode: barcode,
  userId: 'u',
  nickname: 'n',
  rating: rating,
  comment: '',
  createdAt: DateTime.utc(2026, 9, 28),
);

class FakeReviews implements ReviewRepository {
  FakeReviews(this.items);
  List<Review> items;
  Object? error;
  Completer<List<Review>>? pending;
  final List<String> requested = [];

  @override
  Future<List<Review>> forProduct(String barcode) async {
    requested.add(barcode);
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return items.where((r) => r.barcode == barcode).toList();
  }

  @override
  Future<List<Review>> mine() async => items;
  @override
  Future<void> save(ReviewDraft draft) async => throw UnimplementedError();
  @override
  Future<void> delete(String reviewId) async => throw UnimplementedError();
}

void main() {
  late FakeReviews reviews;
  late AppScope scope;

  setUp(() {
    reviews = FakeReviews([]);
    scope = AppScope(
      products: DemoProducts(),
      reviews: reviews,
      community: DemoCommunity(),
      openFoodFacts: HttpOpenFoodFactsRepository(),
      isDemo: true,
      userId: 'demo-user',
    );
  });
  tearDown(() => scope.dispose());

  Future<void> pumpSummary(WidgetTester tester, {Product? forProduct}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: NaTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SummaryFeature(
                context: FeatureContext(
                  scope: scope,
                  product: forProduct,
                  openProduct: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

  String countAt(WidgetTester tester, int star) =>
      tester.widget<Text>(find.byKey(Key('histogram-count-$star'))).data!;

  testWidgets('sem produto (Oficina) mostra orientação e não consulta', (
    tester,
  ) async {
    await pumpSummary(tester);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum produto selecionado'), findsOneWidget);
    expect(reviews.requested, isEmpty);
  });

  testWidgets('notas [1,5,5]: média arredondada só na tela, total e contagens', (
    tester,
  ) async {
    reviews.items = [
      review(1),
      review(5),
      review(5),
      review(2, barcode: 'outro-produto'),
    ];
    await pumpSummary(tester, forProduct: product);
    await tester.pumpAndSettle();
    expect(reviews.requested, [product.barcode]);
    expect(find.text('3,7 de 5 · 3 avaliações'), findsOneWidget);
    expect(find.text('Total de avaliações: 3'), findsOneWidget);
    expect([for (var s = 1; s <= 5; s++) countAt(tester, s)], [
      '1',
      '0',
      '0',
      '0',
      '2',
    ]);
  });

  testWidgets('sem avaliações mostra total 0 e cinco contagens zeradas', (
    tester,
  ) async {
    await pumpSummary(tester, forProduct: product);
    await tester.pumpAndSettle();
    expect(find.text('Sem avaliações'), findsOneWidget);
    expect(find.text('Total de avaliações: 0'), findsOneWidget);
    expect([for (var s = 1; s <= 5; s++) countAt(tester, s)], [
      '0',
      '0',
      '0',
      '0',
      '0',
    ]);
  });

  testWidgets('mostra loading enquanto carrega', (tester) async {
    reviews.pending = Completer<List<Review>>();
    await pumpSummary(tester, forProduct: product);
    await tester.pump();
    expect(find.text('Carregando avaliações…'), findsOneWidget);
    reviews.pending!.complete([review(4)]);
    await tester.pumpAndSettle();
    expect(find.text('Carregando avaliações…'), findsNothing);
    expect(find.text('4,0 de 5 · 1 avaliações'), findsOneWidget);
  });

  testWidgets('erro mostra mensagem segura e retry recarrega', (tester) async {
    reviews.error = const AppFailure(
      FailureKind.network,
      'Sem conexão. Verifique a internet.',
    );
    await pumpSummary(tester, forProduct: product);
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão. Verifique a internet.'), findsOneWidget);
    expect(find.text('Sem avaliações'), findsNothing);

    reviews
      ..error = null
      ..items = [review(3)];
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão. Verifique a internet.'), findsNothing);
    expect(find.text('3,0 de 5 · 1 avaliações'), findsOneWidget);
  });

  testWidgets('entrega pendente aparece como erro, não como lista vazia', (
    tester,
  ) async {
    reviews.error = const FeaturePending('T08');
    await pumpSummary(tester, forProduct: product);
    await tester.pumpAndSettle();
    expect(find.text('Entrega pendente: T08'), findsOneWidget);
    expect(find.text('Sem avaliações'), findsNothing);
  });

  testWidgets('scope.refresh() recarrega o resumo', (tester) async {
    reviews.items = [review(5)];
    await pumpSummary(tester, forProduct: product);
    await tester.pumpAndSettle();
    expect(find.text('5,0 de 5 · 1 avaliações'), findsOneWidget);

    reviews.items = [review(5), review(1)];
    scope.refresh();
    await tester.pumpAndSettle();
    expect(find.text('3,0 de 5 · 2 avaliações'), findsOneWidget);
    expect(reviews.requested.length, 2);
  });

  testWidgets('cabe em 320px com texto a 200%', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    reviews.items = [review(1), review(5), review(5)];
    await pumpSummary(tester, forProduct: product);
    await tester.pumpAndSettle();
    expect(find.text('Total de avaliações: 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}