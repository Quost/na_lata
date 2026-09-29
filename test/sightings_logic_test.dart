import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/features/sightings/sighting_logic.dart';

void main() {
  group('validateSightingField', () {
    test('rejeita vazio ou só espaços', () {
      expect(validateSightingField('').error, SightingError.empty);
      expect(validateSightingField('   ').error, SightingError.empty);
      expect(validateSightingField(null).error, SightingError.empty);
    });

    test('aplica trim e aceita dentro do limite', () {
      final result = validateSightingField('  Mercado do Bairro  ');
      expect(result.isValid, isTrue);
      expect(result.value, 'Mercado do Bairro');
    });

    test('aceita exatamente 100 caracteres', () {
      final texto = 'a' * sightingFieldMaxLength;
      expect(validateSightingField(texto).isValid, isTrue);
    });

    test('rejeita acima de 100 caracteres (conta runes)', () {
      final texto = 'a' * (sightingFieldMaxLength + 1);
      expect(validateSightingField(texto).error, SightingError.tooLong);
    });

    test('conta emoji como um caractere', () {
      final texto = '😀' * sightingFieldMaxLength;
      expect(validateSightingField(texto).isValid, isTrue);
    });
  });

  group('validateSighting', () {
    test('devolve cópia normalizada quando válido', () {
      final result = validateSighting(
        const Sighting(
          barcode: '  demo-1  ',
          store: '  Loja  ',
          city: '  Cidade  ',
        ),
      );
      expect(result.barcode, 'demo-1');
      expect(result.store, 'Loja');
      expect(result.city, 'Cidade');
    });

    test('lança AppFailure de validação quando a loja é vazia', () {
      expect(
        () => validateSighting(
          const Sighting(barcode: 'demo-1', store: '', city: 'Cidade'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.validation,
          ),
        ),
      );
    });

    test('lança AppFailure quando a cidade excede o limite', () {
      expect(
        () => validateSighting(
          Sighting(
            barcode: 'demo-1',
            store: 'Loja',
            city: 'a' * (sightingFieldMaxLength + 1),
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('lança quando o barcode é vazio', () {
      expect(
        () => validateSighting(
          const Sighting(barcode: '  ', store: 'Loja', city: 'Cidade'),
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
