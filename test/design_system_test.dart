import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';

void main() {
  testWidgets('botão bloqueia toques enquanto carrega', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: NaButton(
            label: 'Salvar',
            loading: true,
            onPressed: () => calls++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    expect(calls, 0);
    expect(find.text('Aguarde…'), findsOneWidget);
  });
  testWidgets('nota ausente e erro oferecem estados explícitos', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              const NaRatingBadge(average: null, count: 0),
              NaError(message: 'Sem conexão', onRetry: () => retries++),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Sem avaliações'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });
  testWidgets('card suporta 320px e texto ampliado', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: NaItemCard(
                title: 'Chocolate ao leite com castanhas',
                subtitle: 'Uma marca com nome longo',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
