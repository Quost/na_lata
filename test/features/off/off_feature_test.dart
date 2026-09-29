import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/off/off_feature.dart';

/// OFF sem rede: responde com [response], lança [error] ou espera [pending].
class FakeOpenFoodFacts implements OpenFoodFactsRepository {
  Product? response;
  Object? error;
  Completer<Product?>? pending;
  final lookups = <String>[];

  @override
  Future<Product?> lookup(String barcode) async {
    lookups.add(barcode);
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return response;
  }
}

const leite = Product(
  barcode: '7891000100103',
  name: 'Leite Condensado Integral moça',
  brand: 'nestlé',
  category: 'en:dairies',
);

void main() {
  late FakeOpenFoodFacts off;

  Future<void> pumpFeature(WidgetTester tester, {double textScale = 1}) async {
    final scope = AppScope(
      products: DemoProducts(),
      reviews: DemoReviews(),
      community: DemoCommunity(),
      openFoodFacts: off,
      isDemo: true,
      userId: 'demo-user',
    );
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: OffFeature(
                context: FeatureContext(scope: scope, openProduct: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> search(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextFormField), code);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  setUp(() => off = FakeOpenFoodFacts());

  testWidgets('produto encontrado mostra dados, fonte e aviso sem foto', (
    tester,
  ) async {
    off.response = leite;
    await pumpFeature(tester);
    await search(tester, '7891000100103');
    await tester.pumpAndSettle();
    expect(off.lookups, ['7891000100103']);
    expect(find.text('Leite Condensado Integral moça'), findsOneWidget);
    expect(find.text('Marca: nestlé'), findsOneWidget);
    expect(find.text('Categoria: en:dairies'), findsOneWidget);
    expect(find.text('Código: 7891000100103'), findsOneWidget);
    expect(find.text('Sem foto disponível'), findsOneWidget);
    expect(find.textContaining('Fonte: Open Food Facts'), findsOneWidget);
  });

  testWidgets('produto sem marca e categoria informa ausência', (tester) async {
    off.response = const Product(barcode: '00012345', name: 'Produto sem nome');
    await pumpFeature(tester);
    await search(tester, '00012345');
    await tester.pumpAndSettle();
    expect(off.lookups, ['00012345']);
    expect(find.text('Marca: não informada'), findsOneWidget);
    expect(find.text('Categoria: não informada'), findsOneWidget);
    expect(find.text('Código: 00012345'), findsOneWidget);
  });

  testWidgets('foto que falha ao carregar mostra aviso textual', (
    tester,
  ) async {
    off.response = const Product(
      barcode: '7891000100103',
      name: 'Leite',
      imageUrl: 'https://images.example.org/quebrada.jpg',
    );
    await pumpFeature(tester);
    await search(tester, '7891000100103');
    // O HttpClient do flutter_test responde 400 para imagens de rede.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Sem foto disponível'), findsOneWidget);
  });

  testWidgets('consulta em andamento bloqueia novo envio e mostra loading', (
    tester,
  ) async {
    off.pending = Completer<Product?>();
    await pumpFeature(tester);
    await search(tester, '7891000100103');
    expect(find.text('Consultando Open Food Facts…'), findsOneWidget);
    expect(find.text('Aguarde…'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(off.lookups, hasLength(1));
    off.pending!.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Consultar'), findsOneWidget);
  });

  testWidgets('produto inexistente mostra estado vazio com o código', (
    tester,
  ) async {
    await pumpFeature(tester);
    await search(tester, '7890000000017');
    await tester.pumpAndSettle();
    expect(find.text('Produto não encontrado'), findsOneWidget);
    expect(find.textContaining('7890000000017'), findsWidgets);
  });

  testWidgets('erro mostra mensagem segura e tenta de novo só ao tocar', (
    tester,
  ) async {
    off.error = const AppFailure(
      FailureKind.network,
      'Sem conexão. Verifique sua internet.',
    );
    await pumpFeature(tester);
    await search(tester, '7891000100103');
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão. Verifique sua internet.'), findsOneWidget);
    expect(off.lookups, hasLength(1));

    off
      ..error = null
      ..response = leite;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(off.lookups, ['7891000100103', '7891000100103']);
    expect(find.text('Leite Condensado Integral moça'), findsOneWidget);
  });

  testWidgets('código vazio ou curto não consulta; campo aceita só dígitos', (
    tester,
  ) async {
    await pumpFeature(tester);
    await search(tester, '');
    expect(find.text('Digite o código de barras.'), findsOneWidget);
    await search(tester, '1234567');
    expect(find.text('O código deve ter de 8 a 14 dígitos.'), findsOneWidget);
    expect(off.lookups, isEmpty);

    await tester.enterText(find.byType(TextFormField), '7891-000 100103x99');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '78910001001039');
  });

  testWidgets('resposta após sair da tela não atualiza widget descartado', (
    tester,
  ) async {
    off.pending = Completer<Product?>();
    await pumpFeature(tester);
    await search(tester, '7891000100103');
    await tester.pumpWidget(const SizedBox());
    off.pending!.complete(leite);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resultado cabe em 320px com texto ampliado', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    off.response = leite;
    await pumpFeature(tester, textScale: 2);
    await search(tester, '7891000100103');
    await tester.pumpAndSettle();
    expect(find.text('Leite Condensado Integral moça'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
