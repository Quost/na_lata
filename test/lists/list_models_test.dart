import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/features/lists/list_models.dart';

Matcher failure(FailureKind kind) =>
    isA<AppFailure>().having((e) => e.kind, 'kind', kind);

void main() {
  group('validateListDraft', () {
    test('apara nome, descrição vazia vira null e nasce privada', () {
      final valid = validateListDraft(
        const ProductListDraft(name: '  Mercado  ', description: '   '),
      );
      expect(valid.name, 'Mercado');
      expect(valid.description, isNull);
      expect(valid.visibility, ListVisibility.private);
    });

    test('aceita limites exatos de 60 e 200 caracteres', () {
      final valid = validateListDraft(
        ProductListDraft(name: 'a' * 60, description: 'b' * 200),
      );
      expect(valid.name.length, 60);
      expect(valid.description!.length, 200);
    });

    test('conta caracteres como o banco, não unidades UTF-16', () {
      // 60 emojis = 120 unidades UTF-16, mas 60 caracteres no Postgres.
      expect(
        validateListDraft(ProductListDraft(name: '🥫' * 60)).name.runes.length,
        60,
      );
    });

    test('rejeita nome vazio, nome longo e descrição longa', () {
      for (final draft in [
        const ProductListDraft(name: '   '),
        ProductListDraft(name: 'a' * 61),
        ProductListDraft(name: 'ok', description: 'b' * 201),
      ]) {
        expect(
          () => validateListDraft(draft),
          throwsA(failure(FailureKind.validation)),
        );
      }
    });
  });

  group('productListFromRow', () {
    final row = {
      'id': 'l1',
      'owner_id': 'u1',
      'name': 'Churrasco',
      'description': null,
      'visibility': 'public',
      'created_at': '2026-10-05T12:00:00+00:00',
      'updated_at': '2026-10-05T13:00:00+00:00',
      'list_items': [
        {'count': 3},
      ],
    };

    test('converte linha com contagem embutida', () {
      final list = productListFromRow(row);
      expect(list.id, 'l1');
      expect(list.ownerId, 'u1');
      expect(list.description, isNull);
      expect(list.visibility, ListVisibility.public);
      expect(list.itemCount, 3);
      expect(list.updatedAt.isAfter(list.createdAt), isTrue);
    });

    test('sem contagem ou visibilidade desconhecida assume 0 e privada', () {
      final list = productListFromRow({
        ...row,
        'visibility': 'outra',
        'list_items': <Object>[],
      });
      expect(list.itemCount, 0);
      expect(list.visibility, ListVisibility.private);
    });

    test('linha para escrita nunca leva owner_id nem id', () {
      final data = productListToRow(
        const ProductListDraft(name: 'Feira', description: 'Sábado'),
      );
      expect(data, {
        'name': 'Feira',
        'description': 'Sábado',
        'visibility': 'private',
      });
    });
  });
}
