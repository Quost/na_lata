import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/open_food_facts_repository.dart';
import 'fixtures.dart';

Map<String, dynamic> fixture(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

void main() {
  group('origem dos dados', () {
    final fetchedAt = DateTime.utc(2026, 10, 5, 12, 30);

    test('produto do OFF recebe fonte, link da página e data da consulta', () {
      final product = parseOffProduct(
        fixture(offFound),
        '7891000100103',
        fetchedAt: fetchedAt,
      )!;
      expect(product.source, 'open_food_facts');
      expect(
        product.sourceUrl,
        'https://world.openfoodfacts.org/product/7891000100103',
      );
      expect(product.sourceFetchedAt, fetchedAt);
    });

    test('campos ausentes na resposta não impedem o registro da origem', () {
      final product = parseOffProduct(
        fixture(offIncomplete),
        '7890000000024',
        fetchedAt: fetchedAt,
      )!;
      expect(product.imageUrl, isNull);
      expect(product.source, 'open_food_facts');
      expect(product.sourceFetchedAt, fetchedAt);
    });

    test('sem data de consulta informada, a data fica desconhecida', () {
      final product = parseOffProduct(fixture(offFound), '7891000100103')!;
      expect(product.sourceFetchedAt, isNull);
    });
  });

  test(
    'produto encontrado vira Product com marca e categoria normalizadas',
    () {
      final product = parseOffProduct(fixture(offFound), '7891000100103')!;
      expect(product.barcode, '7891000100103');
      expect(product.name, 'Leite Condensado Integral moça');
      expect(product.brand, 'nestlé');
      expect(product.category, 'en:dairies');
      expect(product.imageUrl, startsWith('https://images.openfoodfacts.org/'));
      expect(product.isDemo, isFalse);
    },
  );

  test(
    'preserva o código consultado, com zeros, mesmo se o OFF normalizar',
    () {
      final product = parseOffProduct(
        fixture(offNormalizedCode),
        '041196910759',
      );
      expect(product!.barcode, '041196910759');
    },
  );

  test('produto sem foto, nome, marca e categoria usa valores ausentes', () {
    final product = parseOffProduct(fixture(offIncomplete), '7890000000024')!;
    expect(product.name, offProductNameFallback);
    expect(product.brand, isNull);
    expect(product.category, isNull);
    expect(product.imageUrl, isNull);
  });

  test('status 0 significa produto inexistente', () {
    expect(parseOffProduct(fixture(offNotFound), '7890000000017'), isNull);
  });

  test('marca ignora entradas vazias e categoria ignora tags inválidas', () {
    final product = parseOffProduct({
      'status': 1,
      'product': {
        'brands': ' ,  Garoto ,Nestlé',
        'categories_tags': [42, '  ', 'en:chocolates'],
        'product_name': 123,
      },
    }, '12345678')!;
    expect(product.brand, 'garoto');
    expect(product.category, 'en:chocolates');
    expect(product.name, offProductNameFallback);
  });

  test('estrutura inesperada é resposta inválida, não produto inexistente', () {
    final invalid = isA<AppFailure>().having(
      (e) => e.kind,
      'kind',
      FailureKind.invalidResponse,
    );
    for (final json in [
      fixture(offMissingProduct),
      <String, dynamic>{'product': <String, dynamic>{}},
      <String, dynamic>{'status': '1', 'product': <String, dynamic>{}},
      <String, dynamic>{'status': 1, 'product': 'texto'},
    ]) {
      expect(() => parseOffProduct(json, '12345678'), throwsA(invalid));
    }
  });
}
