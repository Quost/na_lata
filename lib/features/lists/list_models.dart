import '../../data/clients/app_failure.dart';

const listNameMaxLength = 60;
const listDescriptionMaxLength = 200;
const accountRequiredMessage =
    'Só contas confirmadas podem alterar suas próprias listas.';
const listNotFoundMessage = 'Lista não encontrada. Atualize a tela.';

/// Espelha `product_lists.visibility`; toda lista nasce privada.
enum ListVisibility {
  private('private'),
  public('public');

  const ListVisibility(this.value);
  final String value;

  static ListVisibility parse(String? value) =>
      ListVisibility.values.firstWhere(
        (v) => v.value == value,
        orElse: () => ListVisibility.private,
      );
}

class ProductList {
  const ProductList({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.visibility,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });
  final String id, ownerId, name;
  final String? description;
  final ListVisibility visibility;
  final int itemCount;
  final DateTime createdAt, updatedAt;
}

class ProductListDraft {
  const ProductListDraft({
    required this.name,
    this.description,
    this.visibility = ListVisibility.private,
  });
  final String name;
  final String? description;
  final ListVisibility visibility;
}

/// Mesmas regras do banco: nome 1–60 após trim, descrição opcional até 200.
ProductListDraft validateListDraft(ProductListDraft draft) {
  final name = draft.name.trim();
  if (name.isEmpty) {
    throw const AppFailure(FailureKind.validation, 'Dê um nome para a lista.');
  }
  if (name.runes.length > listNameMaxLength) {
    throw const AppFailure(
      FailureKind.validation,
      'O nome pode ter até $listNameMaxLength caracteres.',
    );
  }
  final description = draft.description?.trim() ?? '';
  if (description.runes.length > listDescriptionMaxLength) {
    throw const AppFailure(
      FailureKind.validation,
      'A descrição pode ter até $listDescriptionMaxLength caracteres.',
    );
  }
  return ProductListDraft(
    name: name,
    description: description.isEmpty ? null : description,
    visibility: draft.visibility,
  );
}

/// Colunas pedidas ao PostgREST; `list_items(count)` evita uma consulta por lista.
const productListColumns =
    'id, owner_id, name, description, visibility, created_at, updated_at, list_items(count)';

ProductList productListFromRow(Map<String, dynamic> row) {
  final items = row['list_items'];
  var count = 0;
  if (items is List && items.isNotEmpty) {
    count =
        ((items.first as Map<String, dynamic>)['count'] as num?)?.toInt() ?? 0;
  }
  return ProductList(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    name: row['name'] as String,
    description: row['description'] as String?,
    visibility: ListVisibility.parse(row['visibility'] as String?),
    itemCount: count,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}

Map<String, dynamic> productListToRow(ProductListDraft draft) => {
  'name': draft.name,
  'description': draft.description,
  'visibility': draft.visibility.value,
};
