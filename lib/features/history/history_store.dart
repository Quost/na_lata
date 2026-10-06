import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models.dart';

/// Quantidade máxima de produtos guardados por conta neste aparelho.
const historyLimit = 50;

/// Chave antiga, global ao aparelho: lista de códigos sem dono.
const legacyHistoryKey = 'na_lata.history.barcodes';

/// Chave do histórico de uma conta. Cada conta tem a sua, no mesmo aparelho.
String historyKeyFor(String userId) => 'na_lata.history.v2.$userId';

/// Produto visto e o momento do último acesso.
class HistoryVisit {
  const HistoryVisit(this.barcode, this.visitedAt);
  final String barcode;
  final DateTime visitedAt;

  @override
  bool operator ==(Object other) =>
      other is HistoryVisit &&
      other.barcode == barcode &&
      other.visitedAt == visitedAt;

  @override
  int get hashCode => Object.hash(barcode, visitedAt);
}

/// Regra pura do histórico: mais recente primeiro, sem repetição e com limite.
///
/// O código é guardado como texto, preservando zeros à esquerda. Rever um
/// produto atualiza o último acesso e o move para o topo. Um código vazio não
/// altera a lista.
List<HistoryVisit> addToHistory(
  List<HistoryVisit> current,
  String barcode,
  DateTime visitedAt, {
  int limit = historyLimit,
}) {
  if (barcode.trim().isEmpty) return List.of(current);
  return [
    HistoryVisit(barcode, visitedAt),
    ...current.where((visit) => visit.barcode != barcode),
  ].take(limit).toList();
}

/// Falha de leitura ou gravação do histórico local.
class HistoryException implements Exception {
  const HistoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Persistência local do histórico de produtos vistos por uma conta.
///
/// O [userId] vem da sessão (`AppScope.userId`); contas diferentes no mesmo
/// aparelho nunca compartilham a lista.
class HistoryStore {
  HistoryStore({
    required this.userId,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  final String userId;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;

  /// Incrementado após cada gravação para as telas abertas recarregarem.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  String get _key => historyKeyFor(userId);

  Future<List<HistoryVisit>> load() async {
    final prefs = await _preferences();
    await _migrateLegacy(prefs);
    return _read(prefs);
  }

  Future<void> record(String barcode) async {
    final prefs = await _preferences();
    await _migrateLegacy(prefs);
    final next = addToHistory(_read(prefs), barcode, _now());
    await _write(prefs, next);
  }

  /// Esvazia somente o histórico da conta atual.
  Future<void> clear() async {
    final prefs = await _preferences();
    if (!await prefs.remove(_key)) {
      throw const HistoryException('Não foi possível limpar o histórico.');
    }
    changes.value++;
  }

  /// Leva o histórico antigo (global) para a conta atual, uma única vez.
  ///
  /// Só migra quando a conta ainda não tem histórico próprio, e remove a chave
  /// antiga depois de copiar, para que nenhuma outra conta a receba também.
  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final legacy = prefs.get(legacyHistoryKey);
    if (legacy == null) return;
    if (!prefs.containsKey(_key) &&
        legacy is List &&
        legacy.every((item) => item is String)) {
      final moment = _now();
      final visits = [
        for (final code in legacy.cast<String>())
          if (code.trim().isNotEmpty) HistoryVisit(code, moment),
      ];
      final unique = <String>{};
      await _write(
        prefs,
        [
          for (final visit in visits)
            if (unique.add(visit.barcode)) visit,
        ].take(historyLimit).toList(),
      );
    }
    // Formato antigo ilegível não pertence a nenhuma conta: descartar.
    if (!await prefs.remove(legacyHistoryKey)) {
      throw const HistoryException('Não foi possível migrar o histórico.');
    }
  }

  List<HistoryVisit> _read(SharedPreferences prefs) {
    final value = prefs.get(_key);
    if (value == null) return [];
    try {
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return [
            for (final item in decoded) _visitFrom(item),
          ].take(historyLimit).toList();
        }
      }
    } on FormatException {
      // cai no erro padronizado abaixo
    }
    throw const HistoryException(
      'O histórico salvo está em um formato inválido. Limpe o histórico.',
    );
  }

  HistoryVisit _visitFrom(Object? item) {
    if (item is Map &&
        item['barcode'] is String &&
        item['visitedAt'] is String) {
      final barcode = item['barcode'] as String;
      final visitedAt = DateTime.tryParse(item['visitedAt'] as String);
      if (barcode.trim().isNotEmpty && visitedAt != null) {
        return HistoryVisit(barcode, visitedAt);
      }
    }
    throw const FormatException('entrada inválida');
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<HistoryVisit> visits,
  ) async {
    final json = jsonEncode([
      for (final visit in visits)
        {
          'barcode': visit.barcode,
          'visitedAt': visit.visitedAt.toIso8601String(),
        },
    ]);
    if (!await prefs.setString(_key, json)) {
      throw const HistoryException('Não foi possível salvar o histórico.');
    }
    changes.value++;
  }
}

/// Contrato da T24: registra que [product] foi visto por [userId] neste aparelho.
///
/// Pensado para ser chamado no callback de abertura de produto, nunca em
/// build. Uma falha ao gravar o histórico não impede abrir o produto: o erro é
/// registrado no console de depuração e a tela de histórico mostrará o problema
/// na próxima leitura.
Future<void> recordVisit(
  Product product, {
  required String userId,
  HistoryStore? store,
}) async {
  try {
    await (store ?? HistoryStore(userId: userId)).record(product.barcode);
  } catch (error) {
    debugPrint('Histórico não atualizado: $error');
  }
}
