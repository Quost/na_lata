import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/review_form/review_form_feature.dart';
import 'package:na_lata/features/review_form/review_validation.dart';

/// Fake próprio: T07 não depende da persistência de T08.
class _FakeReviews implements ReviewRepository {
  final saved = <ReviewDraft>[];
  Completer<void>? pending;
  Object? failure;
  @override
  Future<void> save(ReviewDraft draft) async {
    saved.add(draft);
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<List<Review>> forProduct(String barcode) async => [];
  @override
  Future<List<Review>> mine() async => [];
  @override
  Future<void> delete(String reviewId) async {}
}

const _product = Product(barcode: '0012345678905', name: 'Sardinha em lata');

class _Harness {
  final reviews = _FakeReviews();
  late final scope = AppScope(
    products: DemoProducts(),
    reviews: reviews,
    community: DemoCommunity(),
    openFoodFacts: _NoOff(),
    isDemo: true,
    userId: 'demo-user',
  );
  int refreshes = 0;

  Future<void> pump(WidgetTester tester, {Product? product = _product}) async {
    scope.addListener(() => refreshes++);
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReviewFormFeature(
              context: FeatureContext(
                scope: scope,
                product: product,
                openProduct: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoOff implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}

Future<void> _publish(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Publicar avaliação'));
  await tester.tap(find.text('Publicar avaliação'));
}

void main() {
  group('validação', () {
    test('nota inteira de 1 a 5 é obrigatória', () {
      expect(validateRating(null), isNotNull);
      expect(validateRating(0), isNotNull);
      expect(validateRating(6), isNotNull);
      expect(validateRating(1), isNull);
      expect(validateRating(5), isNull);
    });

    test('comentário aceita até 500 caracteres sem contar as pontas', () {
      expect(validateComment(''), isNull);
      expect(validateComment('a' * 500), isNull);
      expect(validateComment('  ${'a' * 500}  '), isNull);
      expect(validateComment('a' * 501), isNotNull);
    });

    test('buildDraft apara comentário e recusa dados inválidos', () {
      final draft = buildDraft(barcode: '123', rating: 4, comment: ' Bom ');
      expect(draft.rating, 4);
      expect(draft.comment, 'Bom');
      expect(
        () => buildDraft(barcode: '123', rating: null),
        throwsArgumentError,
      );
    });
  });

  testWidgets('sem produto orienta abrir pelo catálogo', (tester) async {
    final h = _Harness();
    await h.pump(tester, product: null);
    expect(find.text('Nenhum produto selecionado'), findsOneWidget);
    expect(find.text('Publicar avaliação'), findsNothing);
    h.scope.dispose();
  });

  testWidgets('sem nota não envia', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _publish(tester);
    await tester.pump();
    expect(find.text('Escolha uma nota de 1 a 5.'), findsOneWidget);
    expect(h.reviews.saved, isEmpty);
    expect(h.refreshes, 0);
    h.scope.dispose();
  });

  testWidgets('envia ReviewDraft, limpa o formulário e chama refresh', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(find.byTooltip('4 estrelas'));
    await tester.enterText(find.byType(TextFormField), '  Ótima no pão.  ');
    await _publish(tester);
    await tester.pumpAndSettle();
    final draft = h.reviews.saved.single;
    expect(draft.barcode, '0012345678905');
    expect(draft.rating, 4);
    expect(draft.comment, 'Ótima no pão.');
    expect(h.refreshes, 1);
    expect(find.text('Avaliação publicada.'), findsOneWidget);
    expect(find.text('Ótima no pão.'), findsNothing);
    h.scope.dispose();
  });

  testWidgets('loading bloqueia segundo envio', (tester) async {
    final h = _Harness();
    h.reviews.pending = Completer<void>();
    await h.pump(tester);
    await tester.tap(find.byTooltip('5 estrelas'));
    await _publish(tester);
    await tester.pump();
    expect(find.text('Aguarde…'), findsOneWidget);
    await tester.tap(find.text('Aguarde…'));
    await tester.pump();
    expect(h.reviews.saved, hasLength(1));
    h.reviews.pending!.complete();
    await tester.pumpAndSettle();
    expect(h.refreshes, 1);
    h.scope.dispose();
  });

  testWidgets('erro mantém dados e não chama refresh', (tester) async {
    final h = _Harness();
    h.reviews.failure = const AppFailure(
      FailureKind.network,
      'Sem conexão. Tente novamente.',
    );
    await h.pump(tester);
    await tester.tap(find.byTooltip('2 estrelas'));
    await tester.enterText(find.byType(TextFormField), 'Muito salgada');
    await _publish(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Avaliação não publicada: Sem conexão. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Muito salgada'), findsOneWidget);
    expect(h.refreshes, 0);
    h.reviews.failure = null;
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(h.reviews.saved.map((d) => d.rating), [2, 2]);
    expect(h.refreshes, 1);
    h.scope.dispose();
  });

  testWidgets('T08 pendente aparece como erro, não sucesso', (tester) async {
    final h = _Harness();
    h.reviews.failure = const FeaturePending('T08 — persistir avaliações');
    await h.pump(tester);
    await tester.tap(find.byTooltip('3 estrelas'));
    await _publish(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Entrega pendente: T08'), findsOneWidget);
    expect(find.text('Avaliação publicada.'), findsNothing);
    h.scope.dispose();
  });
}
