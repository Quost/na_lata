import '../../core/models.dart';
import '../../data/clients/app_failure.dart';

/// Limite de caracteres de cada campo do relato (loja/cidade).
const sightingFieldMaxLength = 100;

/// Campos possíveis de um relato, para direcionar o erro na UI.
enum SightingField { store, city }

/// Erros de validação de um relato.
enum SightingError { empty, tooLong }

/// Resultado da validação de um campo: ou o texto já normalizado (trim) ou o erro.
class SightingFieldValidation {
  const SightingFieldValidation.ok(String this.value) : error = null;
  const SightingFieldValidation.fail(SightingError this.error) : value = null;
  final String? value;
  final SightingError? error;
  bool get isValid => error == null;
}

/// Regra pura (sem Flutter/rede) para poder ser testada de forma automatizada.
/// Conta caracteres (runes) para tratar emojis/acentos como 1 caractere.
SightingFieldValidation validateSightingField(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return const SightingFieldValidation.fail(SightingError.empty);
  }
  if (text.runes.length > sightingFieldMaxLength) {
    return const SightingFieldValidation.fail(SightingError.tooLong);
  }
  return SightingFieldValidation.ok(text);
}

/// Mensagem exibível para um erro de campo.
String sightingErrorMessage(SightingField field, SightingError error) {
  final label = field == SightingField.store ? 'a loja' : 'a cidade';
  return switch (error) {
    SightingError.empty => 'Informe $label.',
    SightingError.tooLong =>
      'O campo pode ter no máximo $sightingFieldMaxLength caracteres.',
  };
}

/// Valida o relato inteiro e devolve uma cópia normalizada (campos com trim).
/// Lança [AppFailure] de validação quando algum campo é inválido — mesmo
/// contrato que o banco espera antes de persistir.
Sighting validateSighting(Sighting sighting) {
  final barcode = sighting.barcode.trim();
  if (barcode.isEmpty) {
    throw const AppFailure(
      FailureKind.validation,
      'Informe o produto do relato.',
    );
  }
  final store = validateSightingField(sighting.store);
  if (!store.isValid) {
    throw AppFailure(
      FailureKind.validation,
      sightingErrorMessage(SightingField.store, store.error!),
    );
  }
  final city = validateSightingField(sighting.city);
  if (!city.isValid) {
    throw AppFailure(
      FailureKind.validation,
      sightingErrorMessage(SightingField.city, city.error!),
    );
  }
  return Sighting(barcode: barcode, store: store.value!, city: city.value!);
}
