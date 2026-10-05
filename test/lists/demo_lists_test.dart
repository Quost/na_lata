import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_lists.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/features/lists/list_models.dart';

Matcher failure(FailureKind kind) =>
    isA<AppFailure>().having((e) => e.kind, 'kind', kind);

void main() {
  late DemoListStore store;
  late DemoListRepository a, b, visitor;

  setUp(() {
    store = DemoListStore();
    a = DemoListRepository(userId: 'a', store: store);
    b = DemoListRepository(userId: 'b', store: store);
    visitor = DemoListRepository(
      userId: 'v',
      confirmedAccount: false,
      store: store,
    );
  });

  test('estado vazio: sem listas e lista inexistente é null', () async {
    expect(await a.mine(), isEmpty);
    expect(await a.byId('nada'), isNull);
    expect(await a.items('nada'), isEmpty);
  });

  test('lista nasce privada e só o dono a enxerga', () async {
    final list = await a.create(const ProductListDraft(name: 'Mercado'));
    await a.addItem(list.id, '7891000100103');

    expect(list.visibility, ListVisibility.private);
    expect((await a.mine()).single.itemCount, 1);
    expect(await b.byId(list.id), isNull);
    expect(await b.items(list.id), isEmpty);
    expect(await b.mine(), isEmpty);
  });

  test('lista pública é legível, mas não editável por outro', () async {
    final list = await a.create(
      const ProductListDraft(name: 'Dicas', visibility: ListVisibility.public),
    );
    await a.addItem(list.id, '7891000100103');

    expect((await b.byId(list.id))!.name, 'Dicas');
    expect(await b.items(list.id), ['7891000100103']);
    await expectLater(
      b.update(list.id, const ProductListDraft(name: 'Invadida')),
      throwsA(failure(FailureKind.unavailable)),
    );
    await expectLater(
      b.addItem(list.id, '123'),
      throwsA(failure(FailureKind.unauthorized)),
    );
    expect(await b.removeItem(list.id, '7891000100103'), isFalse);
    await expectLater(
      b.delete(list.id),
      throwsA(failure(FailureKind.unavailable)),
    );
    expect(await a.items(list.id), ['7891000100103']);
  });

  test('dono edita nome/descrição e mantém data de criação', () async {
    var now = DateTime.utc(2026, 10, 5, 12);
    final repo = DemoListRepository(clock: () => now);
    final list = await repo.create(const ProductListDraft(name: 'Antigo'));
    now = now.add(const Duration(hours: 1));

    final edited = await repo.update(
      list.id,
      const ProductListDraft(name: ' Novo ', description: 'Feira'),
    );
    expect(edited.name, 'Novo');
    expect(edited.description, 'Feira');
    expect(edited.createdAt, list.createdAt);
    expect(edited.updatedAt, now);
  });

  test('produto repetido não duplica e remover é idempotente', () async {
    final list = await a.create(const ProductListDraft(name: 'Mercado'));
    await a.addItem(list.id, '7891000100103');
    await a.addItem(list.id, ' 7891000100103 ');

    expect(await a.items(list.id), ['7891000100103']);
    expect(await a.removeItem(list.id, '7891000100103'), isTrue);
    expect(await a.removeItem(list.id, '7891000100103'), isFalse);
  });

  test('um produto pode estar em várias listas', () async {
    final first = await a.create(const ProductListDraft(name: 'Um'));
    final second = await a.create(const ProductListDraft(name: 'Dois'));
    await a.addItem(first.id, '7891000100103');
    await a.addItem(second.id, '7891000100103');
    await a.removeItem(first.id, '7891000100103');

    expect(await a.items(first.id), isEmpty);
    expect(await a.items(second.id), ['7891000100103']);
  });

  test('excluir a lista limpa os itens; repetir exclusão falha', () async {
    final list = await a.create(const ProductListDraft(name: 'Temporária'));
    await a.addItem(list.id, '7891000100103');

    await a.delete(list.id);
    expect(store.items.containsKey(list.id), isFalse);
    expect(await a.byId(list.id), isNull);
    await expectLater(
      a.delete(list.id),
      throwsA(failure(FailureKind.unavailable)),
    );
  });

  test('visitante sem conta confirmada não cria nem adiciona', () async {
    await expectLater(
      visitor.create(const ProductListDraft(name: 'Minha')),
      throwsA(failure(FailureKind.unauthorized)),
    );
    expect(store.lists, isEmpty);
  });

  test('validação acontece antes de gravar', () async {
    await expectLater(
      a.create(const ProductListDraft(name: '')),
      throwsA(failure(FailureKind.validation)),
    );
    expect(await a.mine(), isEmpty);
  });

  test('favoritos continuam independentes das listas', () async {
    final community = DemoCommunity(initialFavorites: {'demo-leite-1'});
    final list = await a.create(const ProductListDraft(name: 'Mercado'));
    await a.addItem(list.id, 'demo-chocolate-1');

    expect(await community.favorites(), {'demo-leite-1'});
    expect(await a.items(list.id), ['demo-chocolate-1']);
  });
}
