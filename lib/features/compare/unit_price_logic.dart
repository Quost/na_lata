import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';

/// Ponte local para CAT03/PRE03/GEO02, sem alterar contratos compartilhados.
/// A implementação futura deve usar os repositórios do AppScope.
abstract interface class UnitPriceRepository {
  ComparisonWindow window(AppScope scope);
  Future<PackageQuantity?> quantity(Product product);
  Future<List<PriceObservation>> observations(
    String barcode,
    ComparisonWindow window,
  );
}

/// Ausência de integração não é ausência de preços.
class PendingUnitPriceRepository implements UnitPriceRepository {
  const PendingUnitPriceRepository();

  @override
  ComparisonWindow window(AppScope scope) =>
      throw const FeaturePending('CAT03 (#89), PRE03 (#99) e GEO02 (#77)');

  @override
  Future<PackageQuantity?> quantity(Product product) async =>
      throw const FeaturePending('CAT03 (#89)');

  @override
  Future<List<PriceObservation>> observations(
    String barcode,
    ComparisonWindow window,
  ) async => throw const FeaturePending('PRE03 (#99)');
}

class ComparisonWindow {
  ComparisonWindow({
    required this.from,
    required this.until,
    this.cityId,
    required this.regionLabel,
  }) {
    if (!from.isBefore(until)) {
      throw ArgumentError('O início deve preceder o fim do período.');
    }
  }

  final DateTime from, until;
  final String? cityId;
  final String regionLabel;
}

enum QuantityUnit { g, kg, ml, l }

/// Decimal estruturado da CAT03; nunca extrai quantidade do nome/embalagem.
/// Unidades e números ambíguos permanecem desconhecidos.
class PackageQuantity {
  const PackageQuantity(this.value, this.unit);
  final String value;
  final QuantityUnit unit;

  bool get isMass => unit == QuantityUnit.g || unit == QuantityUnit.kg;
  String get baseUnit => isMass ? 'kg' : 'l';

  /// Quantidade em g/ml como fração exata, inclusive frações de g/ml.
  (BigInt, BigInt)? get normalized {
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final scale = parts.length == 1
        ? BigInt.one
        : BigInt.from(10).pow(parts[1].length);
    var amount = BigInt.parse(parts.join());
    if (amount <= BigInt.zero) return null;
    if (unit == QuantityUnit.kg || unit == QuantityUnit.l) {
      amount *= BigInt.from(1000);
    }
    return (amount, scale);
  }
}

class PriceObservation {
  const PriceObservation({
    required this.id,
    required this.barcode,
    required this.cents,
    required this.cityId,
    required this.cityLabel,
    required this.store,
    required this.observedAt,
  });

  final String id, barcode, cityId, cityLabel, store;
  final int cents;
  final DateTime observedAt;
}

/// Última observação na janela [from, until), com desempate estável por ID.
/// Preço negativo/zero e cidade desconhecida não participam do cálculo.
PriceObservation? latestObservation(
  Iterable<PriceObservation> items,
  String barcode,
  ComparisonWindow window,
) {
  final valid =
      items
          .where(
            (p) =>
                p.barcode == barcode &&
                p.cents > 0 &&
                p.cityId.trim().isNotEmpty &&
                (window.cityId == null || p.cityId == window.cityId) &&
                !p.observedAt.isBefore(window.from) &&
                p.observedAt.isBefore(window.until),
          )
          .toList()
        ..sort((a, b) {
          final date = b.observedAt.compareTo(a.observedAt);
          return date != 0 ? date : a.id.compareTo(b.id);
        });
  return valid.isEmpty ? null : valid.first;
}

class UnitCost {
  const UnitCost(this.numerator, this.denominator, this.unit);
  final BigInt numerator, denominator;
  final String unit;

  static UnitCost? calculate(PackageQuantity? quantity, int? cents) {
    final normalized = quantity?.normalized;
    if (normalized == null || cents == null || cents <= 0) return null;
    return UnitCost(
      BigInt.from(cents) * BigInt.from(1000) * normalized.$2,
      normalized.$1,
      quantity!.baseUnit,
    );
  }

  int compareTo(UnitCost other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  /// Arredonda metade para cima apenas para exibir centavos.
  String get formatted {
    final rounded =
        (numerator * BigInt.two + denominator) ~/ (denominator * BigInt.two);
    return '${formatCents(rounded)}/$unit';
  }
}

String formatCents(BigInt cents) {
  final whole = cents ~/ BigInt.from(100);
  final fraction = (cents % BigInt.from(100)).toString().padLeft(2, '0');
  return 'R\$ $whole,$fraction';
}

class ProductUnitPrice {
  ProductUnitPrice({required this.product, this.quantity, this.observation});
  final Product product;
  final PackageQuantity? quantity;
  final PriceObservation? observation;

  UnitCost? get cost => UnitCost.calculate(quantity, observation?.cents);
}

class UnitPriceComparison {
  UnitPriceComparison({required this.window, required this.items});
  final ComparisonWindow window;
  final List<ProductUnitPrice> items;

  String get verdict {
    final a = items[0].cost, b = items[1].cost;
    if (a == null || b == null) {
      return 'Sem vencedor por custo: quantidade ou preço válido ausente.';
    }
    if (a.unit != b.unit) {
      return 'Sem vencedor por custo: massa e volume são incompatíveis.';
    }
    final order = a.compareTo(b);
    if (order == 0) return 'Mesmo custo por ${a.unit}.';
    return '${items[order < 0 ? 0 : 1].product.name} tem menor custo por ${a.unit}.';
  }
}

Future<UnitPriceComparison> loadUnitPrices({
  required UnitPriceRepository repository,
  required AppScope scope,
  required List<Product> products,
}) async {
  if (products.length != 2 || products[0].barcode == products[1].barcode) {
    throw ArgumentError('Selecione dois produtos diferentes.');
  }
  final window = repository.window(scope);
  final items = await Future.wait(
    products.map((product) async {
      final quantity = await repository.quantity(product);
      final observations = await repository.observations(
        product.barcode,
        window,
      );
      return ProductUnitPrice(
        product: product,
        quantity: quantity,
        observation: latestObservation(observations, product.barcode, window),
      );
    }),
  );
  return UnitPriceComparison(window: window, items: items);
}
