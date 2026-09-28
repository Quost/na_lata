import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models.dart';

/// Quantidade máxima de códigos guardados no aparelho.
const historyLimit = 20;

/// Chave usada no SharedPreferences.
const historyKey = 'na_lata.history.barcodes';

/// Regra pura do histórico: mais recente primeiro, sem repetição e com limite.
///
/// O código é guardado como texto, preservando zeros à esquerda. Um código
/// vazio não altera a lista.
List<String> addToHistory(
  List<String> current,
  String barcode, {
  int limit = historyLimit,
}) {
  if (barcode.trim().isEmpty) return List.of(current);
  return [
    barcode,
    ...current.where((code) => code != barcode),
  ].take(limit).toList();
}

/// Falha de leitura ou gravação do histórico local.
class HistoryException implements Exception {
  const HistoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Persistência local do histórico de produtos vistos.
class HistoryStore {
  HistoryStore({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  /// Incrementado após cada gravação para as telas abertas recarregarem.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  Future<List<String>> load() async {
    final prefs = await _preferences();
    return _read(prefs);
  }

  Future<void> record(String barcode) async {
    final prefs = await _preferences();
    final next = addToHistory(_read(prefs), barcode);
    await _write(prefs, next);
  }

  Future<void> clear() async {
    final prefs = await _preferences();
    if (!await prefs.remove(historyKey)) {
      throw const HistoryException('Não foi possível limpar o histórico.');
    }
    changes.value++;
  }

  List<String> _read(SharedPreferences prefs) {
    final value = prefs.get(historyKey);
    if (value == null) return [];
    if (value is List && value.every((item) => item is String)) {
      return value.cast<String>().take(historyLimit).toList();
    }
    throw const HistoryException(
      'O histórico salvo está em um formato inválido. Limpe o histórico.',
    );
  }

  Future<void> _write(SharedPreferences prefs, List<String> codes) async {
    if (!await prefs.setStringList(historyKey, codes)) {
      throw const HistoryException('Não foi possível salvar o histórico.');
    }
    changes.value++;
  }
}

/// Contrato da T24: registra que [product] foi visto neste aparelho.
///
/// Pensado para ser chamado no callback de abertura de produto, nunca em
/// build. Uma falha ao gravar o histórico não impede abrir o produto: o erro é
/// registrado no console de depuração e a tela de histórico mostrará o problema
/// na próxima leitura.
Future<void> recordVisit(Product product, {HistoryStore? store}) async {
  try {
    await (store ?? HistoryStore()).record(product.barcode);
  } catch (error) {
    debugPrint('Histórico não atualizado: $error');
  }
}
