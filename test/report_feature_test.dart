// Testes de T19 (denunciar comentário) — autoria: Andrey Lazarotto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/report/report_feature.dart';
import 'package:na_lata/features/report/report_logic.dart';

final _peerReview = Review(
  id: 'rev1',
  barcode: 'b1',
  userId: 'peer',
  nickname: 'Colega',
  rating: 2,
  comment: 'Não gostei',
  createdAt: DateTime.utc(2026, 1, 2),
);

class _FakeProducts implements ProductRepository {
  @override
  Future<Product?> byBarcode(String barcode) async => null;
  @override
  Future<void> importProduct(Product product) async {}
  @override
  Future<List<Product>> search(ProductQuery query) async => const [];
}

class _FakeReviews implements ReviewRepository {
  _FakeReviews(this._byProduct);
  final Map<String, List<Review>> _byProduct;
  @override
  Future<List<Review>> forProduct(String barcode) async =>
      _byProduct[barcode] ?? const [];
  @override
  Future<List<Review>> mine() async => const [];
  @override
  Future<void> save(ReviewDraft draft) async {}
  @override
  Future<void> delete(String reviewId) async {}
}

class _FakeCommunity implements CommunityRepository {
  _FakeCommunity({this.alwaysConflict = false});
  final bool alwaysConflict;
  final List<(String, String)> reports = [];

  @override
  Future<void> report(String reviewId, String reason) async {
    if (alwaysConflict) {
      throw const AppFailure(FailureKind.conflict, duplicateReportMessage);
    }
    reports.add((reviewId, reason));
  }

  @override
  Future<Set<String>> favorites() async => {};
  @override
  Future<void> setFavorite(String barcode, bool value) async {}
  @override
  Future<List<Sighting>> sightings(String barcode) async => const [];
  @override
  Future<void> addSighting(Sighting sighting) async {}
  @override
  Future<void> setNickname(String nickname) async {}
}

class _FakeOff implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}

AppScope _scopeWith(CommunityRepository community) => AppScope(
  products: _FakeProducts(),
  reviews: _FakeReviews({
    'b1': [_peerReview],
  }),
  community: community,
  openFoodFacts: _FakeOff(),
  isDemo: true,
  userId: 'me',
);

Future<void> _pump(WidgetTester tester, AppScope scope, Product product) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: NaTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReportFeature(
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

void main() {
  testWidgets('motivo é obrigatório para enviar a denúncia', (tester) async {
    final community = _FakeCommunity();
    final scope = _scopeWith(community);
    await _pump(tester, scope, const Product(barcode: 'b1', name: 'Produto'));

    await tester.tap(find.text('Denunciar'));
    await tester.pumpAndSettle();
    expect(find.text('Qual o motivo da denúncia?'), findsOneWidget);

    // Enviar sem escolher motivo: bloqueia e avisa; nada é enviado.
    await tester.tap(find.text('Enviar denúncia'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha um motivo para denunciar.'), findsOneWidget);
    expect(community.reports, isEmpty);

    // Com motivo escolhido, envia com o valor correto.
    await tester.tap(find.text('Spam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar denúncia'));
    await tester.pumpAndSettle();
    expect(community.reports, [('rev1', 'spam')]);
    scope.dispose();
  });

  testWidgets('denúncia duplicada avisa e mantém o comentário visível', (
    tester,
  ) async {
    final community = _FakeCommunity(alwaysConflict: true);
    final scope = _scopeWith(community);
    await _pump(tester, scope, const Product(barcode: 'b1', name: 'Produto'));

    await tester.tap(find.text('Denunciar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ofensa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar denúncia'));
    await tester.pumpAndSettle();

    // Mensagem de duplicidade e comentário permanece na lista (não é excluído).
    expect(find.text(duplicateReportMessage), findsOneWidget);
    expect(find.text('Denúncia enviada'), findsOneWidget);
    expect(find.text('Não gostei'), findsOneWidget);
    scope.dispose();
  });
}
