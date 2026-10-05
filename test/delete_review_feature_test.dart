// Testes de T17 (excluir avaliação) — autoria: Isaac Fonseca.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/design_system/na_lata_ui.dart';
import 'package:na_lata/features/delete_review/delete_review_feature.dart';

Review _review(
  String id, {
  String barcode = 'b1',
  int rating = 4,
  String comment = 'ok',
}) => Review(
  id: id,
  barcode: barcode,
  userId: 'me',
  nickname: 'Eu',
  rating: rating,
  comment: comment,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('DeleteReviewController', () {
    test('confirmar chama delete, refresh e remove o item', () async {
      final deleted = <String>[];
      var refreshed = 0;
      final review = _review('r1');
      final controller = DeleteReviewController(
        loadMine: () async => [review],
        delete: (id) async {
          deleted.add(id);
        },
        refresh: () {
          refreshed++;
        },
        productName: (code) async => 'Produto $code',
      );
      await controller.load();
      expect(controller.status, DeleteLoadStatus.ready);
      expect(controller.items, hasLength(1));

      final ok = await controller.confirmDelete(review);
      expect(ok, isTrue);
      expect(deleted, ['r1']);
      expect(refreshed, 1);
      expect(controller.items, isEmpty);
      expect(controller.deleteError, isNull);
      controller.dispose();
    });

    test('carregar não exclui nada (sem confirmação = cancelar)', () async {
      final deleted = <String>[];
      final controller = DeleteReviewController(
        loadMine: () async => [_review('r1')],
        delete: (id) async {
          deleted.add(id);
        },
        refresh: () {},
        productName: (code) async => null,
      );
      await controller.load();
      expect(deleted, isEmpty);
      controller.dispose();
    });

    test(
      'erro no delete é capturado; item permanece e refresh não roda',
      () async {
        final review = _review('r1');
        var refreshed = 0;
        final controller = DeleteReviewController(
          loadMine: () async => [review],
          delete: (id) async => throw const AppFailure(
            FailureKind.unavailable,
            'Falhou ao excluir.',
          ),
          refresh: () {
            refreshed++;
          },
          productName: (code) async => null,
        );
        await controller.load();
        final ok = await controller.confirmDelete(review);
        expect(ok, isFalse);
        expect(controller.deleteError, 'Falhou ao excluir.');
        expect(controller.items, hasLength(1));
        expect(refreshed, 0);
        controller.dispose();
      },
    );
  });

  testWidgets('cancelar no diálogo não exclui; confirmar exclui', (
    tester,
  ) async {
    final deleted = <String>[];
    final review = _review('r1', comment: 'Comentário');
    final controller = DeleteReviewController(
      loadMine: () async => [review],
      delete: (id) async {
        deleted.add(id);
      },
      refresh: () {},
      productName: (code) async => 'Produto',
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: NaTheme.light,
        home: Scaffold(body: DeleteReviewView(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    // Abre o diálogo e cancela.
    await tester.tap(find.widgetWithText(NaButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir avaliação?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);

    // Abre de novo e confirma.
    await tester.tap(find.widgetWithText(NaButton, 'Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(deleted, ['r1']);
    expect(find.text('Avaliação excluída.'), findsOneWidget);
    controller.dispose();
  });
}
