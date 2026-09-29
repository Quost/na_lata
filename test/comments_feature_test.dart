import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/comments/comments_feature.dart';

const _product = Product(
  barcode: 'demo-leite-1',
  name: 'Leite integral',
  isDemo: true,
);

Review _review(
  String id, {
  required int day,
  required int rating,
  required String comment,
  String nickname = 'Colega',
}) => Review(
  id: id,
  barcode: 'demo-leite-1',
  userId: 'user-$id',
  nickname: nickname,
  rating: rating,
  comment: comment,
  createdAt: DateTime(2026, 9, day),
);

/// Fake em memória; devolve a lista na ordem recebida (sem ordenar), para
/// provar que a ordenação é feita pela própria feature.
class _FakeReviews implements ReviewRepository {
  _FakeReviews(this._byBarcode);
  final Map<String, List<Review>> _byBarcode;
  Object? failure;
  int calls = 0;

  @override
  Future<List<Review>> forProduct(String barcode) async {
    calls++;
    if (failure != null) throw failure!;
    return [...?_byBarcode[barcode]];
  }

  @override
  Future<List<Review>> mine() async => [];
  @override
  Future<void> save(ReviewDraft draft) async {}
  @override
  Future<void> delete(String reviewId) async {}
}

class _NoOff implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}

class _Harness {
  _Harness(Map<String, List<Review>> reviews) : repo = _FakeReviews(reviews);
  final _FakeReviews repo;
  late final scope = AppScope(
    products: DemoProducts(),
    reviews: repo,
    community: DemoCommunity(),
    openFoodFacts: _NoOff(),
    isDemo: true,
    userId: 'demo-user',
  );

  Future<void> pump(WidgetTester tester, {Product? product = _product}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommentsFeature(
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

void main() {
  group('sortNewestFirst', () {
    test('ordena do mais recente ao mais antigo sem mutar a origem', () {
      final input = [
        _review('a', day: 1, rating: 3, comment: ''),
        _review('c', day: 20, rating: 5, comment: ''),
        _review('b', day: 10, rating: 4, comment: ''),
      ];
      final result = sortNewestFirst(input);
      expect(result.map((r) => r.id).toList(), ['c', 'b', 'a']);
      // A lista original permanece intacta.
      expect(input.map((r) => r.id).toList(), ['a', 'c', 'b']);
    });

    test('lista vazia devolve lista vazia', () {
      expect(sortNewestFirst(const []), isEmpty);
    });
  });

  test('formatCommentDate usa dd/MM/aaaa com dois dígitos', () {
    expect(formatCommentDate(DateTime(2026, 9, 5)), '05/09/2026');
    expect(formatCommentDate(DateTime(2026, 12, 31)), '31/12/2026');
  });

  group('CommentsFeature', () {
    testWidgets('lista os comentários com o mais recente no topo', (
      tester,
    ) async {
      final h = _Harness({
        'demo-leite-1': [
          _review('old', day: 1, rating: 2, comment: 'Antigo', nickname: 'Ana'),
          _review(
            'new',
            day: 20,
            rating: 5,
            comment: 'Recente',
            nickname: 'Bia',
          ),
        ],
      });
      await h.pump(tester);
      // Renderizados na ordem mais-recente-primeiro (Bia acima de Ana).
      final recente = tester.getTopLeft(find.text('Bia'));
      final antigo = tester.getTopLeft(find.text('Ana'));
      expect(recente.dy, lessThan(antigo.dy));
      expect(find.text('Recente'), findsOneWidget);
      expect(find.text('Antigo'), findsOneWidget);
      expect(find.text('20/09/2026'), findsOneWidget);
      h.scope.dispose();
    });

    testWidgets('aplica moderateComment na exibição, sem mudar a origem', (
      tester,
    ) async {
      final reviews = {
        'demo-leite-1': [
          _review('x', day: 5, rating: 1, comment: 'Que merda de embalagem.'),
        ],
      };
      final h = _Harness(reviews);
      await h.pump(tester);
      expect(find.text('Que *** de embalagem.'), findsOneWidget);
      expect(find.text('Que merda de embalagem.'), findsNothing);
      // O repositório continua com o texto original (máscara é só de exibição).
      expect(
        reviews['demo-leite-1']!.single.comment,
        'Que merda de embalagem.',
      );
      h.scope.dispose();
    });

    testWidgets('sem produto orienta abrir pelo catálogo', (tester) async {
      final h = _Harness(const {});
      await h.pump(tester, product: null);
      expect(find.text('Nenhum produto selecionado'), findsOneWidget);
      expect(h.repo.calls, 0);
      h.scope.dispose();
    });

    testWidgets('produto sem avaliações mostra estado vazio', (tester) async {
      final h = _Harness(const {'demo-leite-1': []});
      await h.pump(tester);
      expect(find.text('Ainda sem comentários'), findsOneWidget);
      h.scope.dispose();
    });

    testWidgets('comentário vazio aparece como "Sem comentário."', (
      tester,
    ) async {
      final h = _Harness({
        'demo-leite-1': [_review('x', day: 5, rating: 4, comment: '   ')],
      });
      await h.pump(tester);
      expect(find.text('Sem comentário.'), findsOneWidget);
      h.scope.dispose();
    });

    testWidgets('erro mostra mensagem segura e tenta novamente', (
      tester,
    ) async {
      final h = _Harness({
        'demo-leite-1': [_review('x', day: 5, rating: 4, comment: 'Bom')],
      });
      h.repo.failure = const AppFailure(
        FailureKind.network,
        'Sem conexão. Tente novamente.',
      );
      await h.pump(tester);
      expect(find.text('Sem conexão. Tente novamente.'), findsOneWidget);
      h.repo.failure = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Bom'), findsOneWidget);
      h.scope.dispose();
    });

    testWidgets('refresh recarrega os comentários', (tester) async {
      final reviews = {
        'demo-leite-1': [_review('x', day: 5, rating: 4, comment: 'Primeiro')],
      };
      final h = _Harness(reviews);
      await h.pump(tester);
      expect(find.text('Primeiro'), findsOneWidget);
      reviews['demo-leite-1'] = [
        _review('y', day: 6, rating: 5, comment: 'Segundo'),
        ...reviews['demo-leite-1']!,
      ];
      h.scope.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Segundo'), findsOneWidget);
      expect(find.text('Primeiro'), findsOneWidget);
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
      final h = _Harness({
        'demo-leite-1': [
          _review(
            'x',
            day: 5,
            rating: 4,
            comment: 'Comentário de exemplo bem longo para testar a quebra.',
            nickname: 'Nome de usuário bastante extenso',
          ),
        ],
      });
      await h.pump(tester);
      expect(tester.takeException(), isNull);
      h.scope.dispose();
    });
  });
}
