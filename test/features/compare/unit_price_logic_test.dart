import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/features/compare/unit_price_logic.dart';

void main() {
  test('500 g a R\$10 resulta em R\$20/kg', () {
    expect(
      UnitCost.calculate(
        const PackageQuantity('500', QuantityUnit.g),
        1000,
      )!.formatted,
      'R\$ 20,00/kg',
    );
  });

  test('converte g/kg e ml/l sem misturar as dimensões', () {
    final gram = UnitCost.calculate(
      const PackageQuantity('500', QuantityUnit.g),
      1000,
    )!;
    final kilo = UnitCost.calculate(
      const PackageQuantity('0.5', QuantityUnit.kg),
      1000,
    )!;
    final ml = UnitCost.calculate(
      const PackageQuantity('250', QuantityUnit.ml),
      1000,
    )!;
    final liter = UnitCost.calculate(
      const PackageQuantity('0.25', QuantityUnit.l),
      1000,
    )!;
    expect(gram.compareTo(kilo), 0);
    expect(ml.compareTo(liter), 0);
    expect(ml.formatted, 'R\$ 40,00/l');
    expect(gram.unit, isNot(ml.unit));
  });

  test('centavos, meio centavo e comparação antes do arredondamento', () {
    final a = UnitCost.calculate(
      const PackageQuantity('3000', QuantityUnit.g),
      100,
    )!;
    final b = UnitCost.calculate(
      const PackageQuantity('3001', QuantityUnit.g),
      100,
    )!;
    expect(a.formatted, 'R\$ 0,33/kg');
    expect(b.formatted, 'R\$ 0,33/kg');
    expect(a.compareTo(b), greaterThan(0));
    expect(
      UnitCost.calculate(
        const PackageQuantity('2000', QuantityUnit.g),
        201,
      )!.formatted,
      'R\$ 1,01/kg',
    );
    expect(
      UnitCost.calculate(
        const PackageQuantity('0.3', QuantityUnit.g),
        1,
      )!.formatted,
      'R\$ 33,33/kg',
    );
  });

  test('quantidade ausente, zero, negativa ou ambígua não gera custo', () {
    expect(UnitCost.calculate(null, 1000), isNull);
    for (final value in [
      '0',
      '-1',
      'NaN',
      'Infinity',
      '2x500',
      '500 g',
      '1,5',
      '',
    ]) {
      expect(
        UnitCost.calculate(PackageQuantity(value, QuantityUnit.g), 1000),
        isNull,
      );
    }
    for (final price in [null, 0, -1]) {
      expect(
        UnitCost.calculate(const PackageQuantity('500', QuantityUnit.g), price),
        isNull,
      );
    }
  });

  test(
    'último relato respeita produto, cidade e observedAt; desempate por ID',
    () {
      final from = DateTime.utc(2026, 9);
      final until = DateTime.utc(2026, 10);
      final window = ComparisonWindow(
        from: from,
        until: until,
        cityId: '1',
        regionLabel: 'Cidade/SC',
      );
      PriceObservation observation(
        String id,
        DateTime at, {
        String city = '1',
        String barcode = 'p',
        int cents = 100,
      }) => PriceObservation(
        id: id,
        barcode: barcode,
        cents: cents,
        cityId: city,
        cityLabel: 'Cidade/SC',
        store: 'Loja',
        observedAt: at,
      );
      final last = DateTime.utc(2026, 9, 29);
      final values = [
        observation('first', from),
        observation('b', last),
        observation('a', last),
        observation('other-city', last.add(const Duration(days: 1)), city: '2'),
        observation('other-product', last, barcode: 'q'),
        observation('old', from.subtract(const Duration(seconds: 1))),
        observation('end-exclusive', until),
        observation('zero', last.add(const Duration(hours: 1)), cents: 0),
        observation('unknown-city', last, city: ''),
      ];
      expect(latestObservation(values, 'p', window)!.id, 'a');
      expect(latestObservation(values.reversed, 'p', window)!.id, 'a');
      expect(latestObservation([], 'p', window), isNull);
      final all = ComparisonWindow(
        from: from,
        until: until,
        regionLabel: 'Todas as regiões',
      );
      expect(latestObservation(values, 'p', all)!.id, 'other-city');
    },
  );
}
