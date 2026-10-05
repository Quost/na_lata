import '../features/lists/list_models.dart';
import 'clients/app_failure.dart';
import 'list_repository.dart';

/// Armazenamento compartilhado entre usuários fictícios, para simular A/B.
class DemoListStore {
  final Map<String, ProductList> lists = {};
  final Map<String, List<String>> items = {};
  var _nextId = 1;
  String nextId() => 'demo-list-${_nextId++}';
}

/// Fake com as mesmas regras da RLS: privada só para o dono, escrita exige
/// conta confirmada, item não duplica e excluir a lista remove os itens.
class DemoListRepository implements ListRepository {
  DemoListRepository({
    this.userId = 'demo-user',
    this.confirmedAccount = true,
    DemoListStore? store,
    DateTime Function()? clock,
  }) : store = store ?? DemoListStore(),
       _clock = clock ?? (() => DateTime.now().toUtc());

  final String userId;
  final bool confirmedAccount;
  final DemoListStore store;
  final DateTime Function() _clock;

  bool _canRead(ProductList list) =>
      list.ownerId == userId || list.visibility == ListVisibility.public;

  ProductList? _own(String id) {
    final list = store.lists[id];
    return list != null && list.ownerId == userId ? list : null;
  }

  void _requireConfirmed() {
    if (!confirmedAccount) {
      throw const AppFailure(FailureKind.unauthorized, accountRequiredMessage);
    }
  }

  ProductList _withCount(ProductList list) => ProductList(
    id: list.id,
    ownerId: list.ownerId,
    name: list.name,
    description: list.description,
    visibility: list.visibility,
    itemCount: store.items[list.id]?.length ?? 0,
    createdAt: list.createdAt,
    updatedAt: list.updatedAt,
  );

  @override
  Future<List<ProductList>> mine() async =>
      store.lists.values
          .where((l) => l.ownerId == userId)
          .map(_withCount)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<ProductList?> byId(String id) async {
    final list = store.lists[id];
    return list != null && _canRead(list) ? _withCount(list) : null;
  }

  @override
  Future<ProductList> create(ProductListDraft draft) async {
    final valid = validateListDraft(draft);
    _requireConfirmed();
    final now = _clock();
    final list = ProductList(
      id: store.nextId(),
      ownerId: userId,
      name: valid.name,
      description: valid.description,
      visibility: valid.visibility,
      itemCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    store.lists[list.id] = list;
    store.items[list.id] = [];
    return list;
  }

  @override
  Future<ProductList> update(String id, ProductListDraft draft) async {
    final valid = validateListDraft(draft);
    final previous = _own(id);
    if (previous == null) {
      throw const AppFailure(FailureKind.unavailable, listNotFoundMessage);
    }
    _requireConfirmed();
    final list = ProductList(
      id: id,
      ownerId: userId,
      name: valid.name,
      description: valid.description,
      visibility: valid.visibility,
      itemCount: 0,
      createdAt: previous.createdAt,
      updatedAt: _clock(),
    );
    store.lists[id] = list;
    return _withCount(list);
  }

  @override
  Future<void> delete(String id) async {
    if (_own(id) == null) {
      throw const AppFailure(FailureKind.unavailable, listNotFoundMessage);
    }
    store.lists.remove(id);
    store.items.remove(id); // equivalente ao on delete cascade
  }

  @override
  Future<List<String>> items(String listId) async {
    final list = store.lists[listId];
    if (list == null || !_canRead(list)) return const [];
    return [...?store.items[listId]];
  }

  @override
  Future<void> addItem(String listId, String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) {
      throw const AppFailure(FailureKind.validation, 'Produto inválido.');
    }
    _requireConfirmed();
    if (_own(listId) == null) {
      throw const AppFailure(FailureKind.unauthorized, accountRequiredMessage);
    }
    final items = store.items[listId]!;
    if (!items.contains(code)) items.add(code);
  }

  @override
  Future<bool> removeItem(String listId, String barcode) async {
    if (_own(listId) == null) return false;
    return store.items[listId]!.remove(barcode.trim());
  }
}
