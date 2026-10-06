import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/app.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/navigation/deep_links.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/features/lists/list_models.dart';

class _FakePlatform implements DeepLinkPlatform {
  final StreamController<String> controller = StreamController.broadcast();
  final List<Uri> shared = [];
  String? initial;

  @override
  Future<String?> initialLink() async {
    final link = initial;
    initial = null;
    return link;
  }

  @override
  Stream<String> get links => controller.stream;

  @override
  Future<void> share(Uri uri) async => shared.add(uri);
}

class _FakeContentSource implements DeepLinkContentSource {
  _FakeContentSource({this.missingList = false});

  final bool missingList;

  @override
  Future<Product?> product(String barcode) async =>
      Product(barcode: barcode, name: 'Leite de teste');

  @override
  Future<SharedProfile?> profile(String id) async =>
      SharedProfile(id: id, nickname: 'Perfil público');

  @override
  Future<SharedProductList?> list(String id) async => missingList
      ? null
      : SharedProductList(
          list: ProductList(
            id: id,
            ownerId: 'owner',
            name: 'Lista compartilhada',
            visibility: ListVisibility.public,
            itemCount: 1,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
          barcodes: const ['000123456789'],
        );
}

AppScope _scope() => AppScope(
  products: DemoProducts(),
  reviews: DemoReviews(),
  community: DemoCommunity(),
  openFoodFacts: HttpOpenFoodFactsRepository(),
  isDemo: true,
  userId: 'demo-user',
);

void main() {
  testWidgets(
    'cold-start link opens product after app bootstrap and shares URI',
    (tester) async {
      final scope = _scope();
      final platform = _FakePlatform()
        ..initial = 'nalata://product/000123456789';
      addTearDown(scope.dispose);
      addTearDown(platform.controller.close);

      await tester.pumpWidget(
        NaLataApp(
          scope: scope,
          deepLinkResolver: DeepLinkResolver(_FakeContentSource()),
          deepLinkPlatform: platform,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Leite de teste'), findsWidgets);
      await tester.tap(find.byTooltip('Compartilhar produto'));
      await tester.pump();
      expect(
        platform.shared.single.toString(),
        'nalata://product/000123456789',
      );
    },
  );

  testWidgets('warm-start malformed or inaccessible link shows unavailable', (
    tester,
  ) async {
    final scope = _scope();
    final platform = _FakePlatform();
    addTearDown(scope.dispose);
    addTearDown(platform.controller.close);

    await tester.pumpWidget(
      NaLataApp(
        scope: scope,
        deepLinkResolver: DeepLinkResolver(_FakeContentSource()),
        deepLinkPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();

    platform.controller.add('nalata://profile/not-a-uuid');
    await tester.pumpAndSettle();
    expect(find.text('Conteúdo indisponível'), findsOneWidget);
    expect(find.text('Não foi possível abrir este link'), findsOneWidget);
  });

  testWidgets('list link displays authorized content and shares only its ID', (
    tester,
  ) async {
    final scope = _scope();
    final platform = _FakePlatform()
      ..initial = 'nalata://list/22222222-2222-4222-8222-222222222222';
    addTearDown(scope.dispose);
    addTearDown(platform.controller.close);

    await tester.pumpWidget(
      NaLataApp(
        scope: scope,
        deepLinkResolver: DeepLinkResolver(_FakeContentSource()),
        deepLinkPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lista compartilhada'), findsOneWidget);
    expect(find.text('000123456789'), findsOneWidget);
    await tester.tap(find.byTooltip('Compartilhar lista'));
    await tester.pump();
    expect(
      platform.shared.single.toString(),
      'nalata://list/22222222-2222-4222-8222-222222222222',
    );
  });

  testWidgets('profile link shares its public UUID without account details', (
    tester,
  ) async {
    const profileId = '11111111-1111-4111-8111-111111111111';
    final scope = _scope();
    final platform = _FakePlatform()..initial = 'nalata://profile/$profileId';
    addTearDown(scope.dispose);
    addTearDown(platform.controller.close);

    await tester.pumpWidget(
      NaLataApp(
        scope: scope,
        deepLinkResolver: DeepLinkResolver(_FakeContentSource()),
        deepLinkPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perfil público'), findsOneWidget);
    await tester.tap(find.byTooltip('Compartilhar perfil'));
    await tester.pump();
    expect(platform.shared.single.toString(), 'nalata://profile/$profileId');
    expect(platform.shared.single.queryParameters, isEmpty);
  });

  testWidgets('cold-start missing private list does not crash', (tester) async {
    final scope = _scope();
    final platform = _FakePlatform()
      ..initial = 'nalata://list/22222222-2222-4222-8222-222222222222';
    addTearDown(scope.dispose);
    addTearDown(platform.controller.close);

    await tester.pumpWidget(
      NaLataApp(
        scope: scope,
        deepLinkResolver: DeepLinkResolver(
          _FakeContentSource(missingList: true),
        ),
        deepLinkPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Conteúdo indisponível'), findsOneWidget);
  });
}
