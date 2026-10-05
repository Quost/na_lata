import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/edit_review/edit_review_feature.dart';

/// Fake em memória com upsert real (DemoReviews) e falhas sob comando.
class _FlakyReviews extends DemoReviews {
  Object? mineFailure;
  Object? saveFailure;
  int saves = 0;
  @override
  Future<List<Review>> mine() async {
    if (mineFailure != null) throw mineFailure!;
    return super.mine();
  }

  @override
  Future<void> save(ReviewDraft draft) async {
    saves++;
    if (saveFailure != null) throw saveFailure!;
    return super.save(draft);
  }
}

class _NoOff implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}

const _chocolate = Product(
  barcode: 'demo-chocolate-1',
  name: 'Chocolate ao leite',
  isDemo: true,
);
const _leite = Product(
  barcode: 'demo-leite-1',
  name: 'Leite integral',
  isDemo: true,
);

class _Harness {
  final reviews = _FlakyReviews();
  late final scope = AppScope(
    products: DemoProducts(),
    reviews: reviews,
    community: DemoCommunity(),
    openFoodFacts: _NoOff(),
    isDemo: true,
    userId: 'demo-user',
  );
  int refreshes = 0;

  Future<void> pump(
    WidgetTester tester, {
    Product? product = _chocolate,
  }) async {
    scope.addListener(() => refreshes++);
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EditReviewFeature(
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
    await tester.pumpAndSettle();
  }
}

String _commentText(WidgetTester tester) =>
    tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text;

int _filledStars() => find.byIcon(Icons.star_rounded).evaluate().length;

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<NaButton>(find.byType(NaButton)).onPressed != null;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('carrega o formulário preenchido com a avaliação existente', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.textContaining('Avaliada em'), findsOneWidget);
    expect(_filledStars(), 2);
    expect(_commentText(tester), 'Achei muito doce.');
    expect(_saveEnabled(tester), isFalse, reason: 'nada mudou ainda');
    h.scope.dispose();
  });

  testWidgets('salva sem criar nova avaliação e atualiza os resumos', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    final before = await h.reviews.forProduct('demo-chocolate-1');
    await _tap(tester, find.byTooltip('Editar para 5 estrelas'));
    await tester.enterText(find.byType(TextFormField), '  Melhorou muito!  ');
    await tester.pump();
    expect(_saveEnabled(tester), isTrue);
    await _tap(tester, find.text('Salvar alterações'));

    final after = await h.reviews.forProduct('demo-chocolate-1');
    expect(after, hasLength(before.length));
    final mine = (await h.reviews.mine())
        .where((r) => r.barcode == 'demo-chocolate-1')
        .toList();
    expect(mine.single.id, 'demo-review-2');
    expect(mine.single.rating, 5);
    expect(mine.single.comment, 'Melhorou muito!');
    expect(h.refreshes, greaterThanOrEqualTo(1));
    expect(find.text('Avaliação atualizada.'), findsOneWidget);
    expect(_commentText(tester), 'Melhorou muito!');
    expect(_saveEnabled(tester), isFalse);
    h.scope.dispose();
  });

  testWidgets('comentário é limitado a 500 caracteres', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.enterText(find.byType(TextFormField), 'a' * 600);
    await tester.pump();
    expect(_commentText(tester).length, 500);
    await _tap(tester, find.text('Salvar alterações'));
    final mine = await h.reviews.mine();
    expect(
      mine.firstWhere((r) => r.barcode == 'demo-chocolate-1').comment,
      hasLength(500),
    );
    h.scope.dispose();
  });

  testWidgets('descartar restaura a avaliação salva', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _tap(tester, find.byTooltip('Editar para 4 estrelas'));
    await tester.enterText(find.byType(TextFormField), 'Rascunho');
    await tester.pump();
    await _tap(tester, find.text('Descartar alterações'));
    expect(_filledStars(), 2);
    expect(_commentText(tester), 'Achei muito doce.');
    expect(h.reviews.saves, 0);
    h.scope.dispose();
  });

  testWidgets('sem avaliação própria mostra estado vazio', (tester) async {
    final h = _Harness();
    await h.pump(tester, product: _leite);
    expect(find.text('Você ainda não avaliou este produto'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    h.scope.dispose();
  });

  testWidgets('após publicar pela T07, o formulário aparece', (tester) async {
    final h = _Harness();
    await h.pump(tester, product: _leite);
    await h.reviews.save(
      const ReviewDraft(barcode: 'demo-leite-1', rating: 3, comment: 'Ok'),
    );
    h.scope.refresh();
    await tester.pumpAndSettle();
    expect(_filledStars(), 3);
    expect(_commentText(tester), 'Ok');
    h.scope.dispose();
  });

  testWidgets('tela de 320 px com texto em 200% não estoura o layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = _Harness();
    await h.pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Salvar alterações'), findsOneWidget);
    h.scope.dispose();
  });

  testWidgets('sem produto orienta abrir pelo catálogo', (tester) async {
    final h = _Harness();
    await h.pump(tester, product: null);
    expect(find.text('Nenhum produto selecionado'), findsOneWidget);
    h.scope.dispose();
  });

  testWidgets('erro ao carregar oferece tentar novamente', (tester) async {
    final h = _Harness();
    h.reviews.mineFailure = const AppFailure(
      FailureKind.network,
      'Sem conexão. Tente novamente.',
    );
    await h.pump(tester);
    expect(find.text('Sem conexão. Tente novamente.'), findsOneWidget);
    h.reviews.mineFailure = null;
    await _tap(tester, find.text('Tentar novamente'));
    expect(_commentText(tester), 'Achei muito doce.');
    h.scope.dispose();
  });

  testWidgets('erro ao salvar mantém a edição e não atualiza resumos', (
    tester,
  ) async {
    final h = _Harness();
    h.reviews.saveFailure = const AppFailure(
      FailureKind.timeout,
      'Tempo esgotado.',
    );
    await h.pump(tester);
    await _tap(tester, find.byTooltip('Editar para 4 estrelas'));
    await _tap(tester, find.text('Salvar alterações'));
    expect(find.text('Alteração não salva: Tempo esgotado.'), findsOneWidget);
    expect(_filledStars(), 4);
    expect(h.refreshes, 0);
    h.reviews.saveFailure = null;
    await _tap(tester, find.text('Tentar novamente'));
    expect(find.text('Avaliação atualizada.'), findsOneWidget);
    expect(
      (await h.reviews.mine())
          .firstWhere((r) => r.barcode == 'demo-chocolate-1')
          .rating,
      4,
    );
    h.scope.dispose();
  });
}
