import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/lists/list_models.dart';
import 'clients/app_failure.dart';
import 'clients/backend_client.dart';

/// LIS01 — listas de produtos. Independente de favoritos (CommunityRepository).
abstract interface class ListRepository {
  /// Listas do usuário da sessão, mais recentes primeiro.
  Future<List<ProductList>> mine();

  /// Lista própria ou pública; null quando não existe ou é privada de outro.
  Future<ProductList?> byId(String id);
  Future<ProductList> create(ProductListDraft draft);
  Future<ProductList> update(String id, ProductListDraft draft);

  /// Exclui a lista e seus itens. Falha se nenhuma lista própria foi apagada.
  Future<void> delete(String id);

  /// Barcodes da lista, na ordem em que foram adicionados.
  Future<List<String>> items(String listId);

  /// Idempotente: repetir o mesmo produto não duplica.
  Future<void> addItem(String listId, String barcode);

  /// Retorna false quando o produto já não estava na lista.
  Future<bool> removeItem(String listId, String barcode);
}

class SupabaseListRepository implements ListRepository {
  SupabaseListRepository(this.client);
  final BackendClient client;

  @override
  Future<List<ProductList>> mine() async {
    final userId = client.requireUserId;
    final rows = await client.request(
      (db) => db
          .from('product_lists')
          .select(productListColumns)
          .eq('owner_id', userId)
          .order('updated_at', ascending: false),
    );
    return rows.map(productListFromRow).toList();
  }

  @override
  Future<ProductList?> byId(String id) async {
    final row = await client.request(
      (db) => db
          .from('product_lists')
          .select(productListColumns)
          .eq('id', id)
          .maybeSingle(),
    );
    return row == null ? null : productListFromRow(row);
  }

  @override
  Future<ProductList> create(ProductListDraft draft) async {
    final valid = validateListDraft(draft);
    final userId = client.requireUserId; // nunca aceitar owner_id da UI
    final row = await _write(
      (db) => db
          .from('product_lists')
          .insert({...productListToRow(valid), 'owner_id': userId})
          .select(productListColumns)
          .single(),
    );
    return productListFromRow(row);
  }

  @override
  Future<ProductList> update(String id, ProductListDraft draft) async {
    final valid = validateListDraft(draft);
    final userId = client.requireUserId;
    final rows = await _write(
      (db) => db
          .from('product_lists')
          .update(productListToRow(valid))
          .eq('id', id)
          .eq('owner_id', userId)
          .select(productListColumns),
    );
    // UPDATE que afeta 0 linhas não lança erro: conferir o retorno.
    if (rows.isEmpty) {
      throw const AppFailure(FailureKind.unavailable, listNotFoundMessage);
    }
    return productListFromRow(rows.first);
  }

  @override
  Future<void> delete(String id) async {
    final userId = client.requireUserId;
    final rows = await client.request(
      (db) => db
          .from('product_lists')
          .delete()
          .eq('id', id)
          .eq('owner_id', userId)
          .select('id'),
    );
    if (rows.isEmpty) {
      throw const AppFailure(FailureKind.unavailable, listNotFoundMessage);
    }
  }

  @override
  Future<List<String>> items(String listId) async {
    final rows = await client.request(
      (db) => db
          .from('list_items')
          .select('barcode')
          .eq('list_id', listId)
          .order('created_at'),
    );
    return rows.map((row) => row['barcode'] as String).toList();
  }

  @override
  Future<void> addItem(String listId, String barcode) async {
    final code = _requireBarcode(barcode);
    client.requireUserId;
    // RLS confere se a lista é do usuário; a PK (list_id, barcode) barra duplicata.
    await _write(
      (db) => db
          .from('list_items')
          .upsert(
            {'list_id': listId, 'barcode': code},
            onConflict: 'list_id,barcode',
            ignoreDuplicates: true,
          ),
    );
  }

  @override
  Future<bool> removeItem(String listId, String barcode) async {
    final code = _requireBarcode(barcode);
    client.requireUserId;
    final rows = await client.request(
      (db) => db
          .from('list_items')
          .delete()
          .eq('list_id', listId)
          .eq('barcode', code)
          .select('barcode'),
    );
    return rows.isNotEmpty;
  }

  /// Escritas novas exigem conta confirmada; a RLS responde 42501 ao visitante.
  Future<T> _write<T>(Future<T> Function(SupabaseClient db) action) async {
    try {
      return await client.request(action);
    } on AppFailure catch (error) {
      if (error.kind == FailureKind.unauthorized) {
        throw const AppFailure(
          FailureKind.unauthorized,
          accountRequiredMessage,
        );
      }
      rethrow;
    }
  }
}

String _requireBarcode(String barcode) {
  final code = barcode.trim();
  if (code.isEmpty) {
    throw const AppFailure(FailureKind.validation, 'Produto inválido.');
  }
  return code;
}
