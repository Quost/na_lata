import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/moderation/comment_moderator.dart';
import 'package:na_lata/features/moderation/moderation_feature.dart';

AppScope makeScope() => AppScope(
  products: DemoProducts(),
  reviews: DemoReviews(),
  community: DemoCommunity(),
  openFoodFacts: HttpOpenFoodFactsRepository(),
  isDemo: true,
  userId: 'demo-user',
);

void main() {
  group('moderateComment', () {
    test('ignora caixa e acentos e mantém pontuação', () {
      expect(moderateComment('Uma MÊRDA!'), 'Uma ***!');
      expect(moderateComment('Você é um imbécil.'), 'Você é um ***.');
    });

    test('substitui palavras inteiras, não trechos de outras palavras', () {
      expect(
        moderateComment('IDIOTA, idiotice e super-idiota.'),
        '***, idiotice e super-***.',
      );
    });

    test('preserva crítica comum, acentos e texto original', () {
      const original = 'O produto é péssimo e parece lixo.';
      expect(moderateComment(original), original);
      expect(original, 'O produto é péssimo e parece lixo.');
    });

    test('trata acento combinante e entrada vazia', () {
      expect(moderateComment('idiota\u0301!'), '***!');
      expect(moderateComment(''), '');
      expect(moderateComment('   '), '   ');
    });
  });

  group('ModerationFeature', () {
    testWidgets('demonstra máscara e preserva texto de entrada', (
      tester,
    ) async {
      final scope = makeScope();
      await tester.pumpWidget(
        MaterialApp(
          theme: NaTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModerationFeature(
                context: FeatureContext(scope: scope, openProduct: (_) {}),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data == 'A embalagem é uma ***, mas o produto é ótimo.',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data == 'A embalagem é uma merda, mas o produto é ótimo.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Ótimo produto, idiota!');
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText && widget.data == 'Ótimo produto, ***!',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data == 'Ótimo produto, idiota!',
        ),
        findsOneWidget,
      );
      scope.dispose();
    });

    testWidgets('mostra estado vazio e funciona sem produto', (tester) async {
      final scope = makeScope();
      await tester.pumpWidget(
        MaterialApp(
          theme: NaTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModerationFeature(
                context: FeatureContext(scope: scope, openProduct: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(find.text('Comentário vazio'), findsOneWidget);
      expect(
        find.text('Demonstração local; nenhum produto selecionado.'),
        findsOneWidget,
      );
      scope.dispose();
    });
  });
}
