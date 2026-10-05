/// Grandeza física da embalagem. Massa e volume nunca se convertem entre si.
enum PackageDimension { mass, volume }

/// Unidades canônicas aceitas. [baseFactor] diz quanto vale 1 da unidade na
/// base da grandeza (g para massa, ml para volume).
enum PackageUnit {
  g('g', PackageDimension.mass, 1),
  kg('kg', PackageDimension.mass, 1000),
  ml('ml', PackageDimension.volume, 1),
  l('l', PackageDimension.volume, 1000);

  const PackageUnit(this.symbol, this.dimension, this.baseFactor);
  final String symbol;
  final PackageDimension dimension;
  final int baseFactor;

  /// Reconhece somente g, kg, ml e l (sem diferenciar maiúsculas); qualquer
  /// outra coisa (oz, cl, un, tipos inesperados) é desconhecida.
  static PackageUnit? fromSymbol(Object? value) {
    if (value is! String) return null;
    final text = value.trim().toLowerCase();
    for (final unit in values) {
      if (unit.symbol == text) return unit;
    }
    return null;
  }
}

/// De onde veio o tamanho. Gravado no banco em `products.package_source`.
enum PackageSizeSource {
  /// Campos estruturados do OFF (`product_quantity` + `product_quantity_unit`).
  offStructured('off_structured'),

  /// Texto simples e inequívoco do campo `quantity` do OFF (ex.: "500 g").
  offText('off_text');

  const PackageSizeSource(this.code);
  final String code;

  static PackageSizeSource? fromCode(Object? value) {
    if (value is! String) return null;
    for (final source in values) {
      if (source.code == value) return source;
    }
    return null;
  }
}

/// Quantidade positiva de uma embalagem, com unidade canônica e origem.
///
/// Só existe com dados válidos: o construtor é privado e [tryCreate] devolve
/// null para ausente, zero, negativo, não finito ou fora dos limites. Assim,
/// "desconhecido" é sempre `null` e nunca entra em cálculo.
class PackageSize {
  const PackageSize._(this.quantity, this.unit, this.source);

  /// Limites na unidade informada, iguais aos do CHECK do banco.
  static const minQuantity = 0.001;
  static const maxQuantity = 1000000.0;

  final double quantity;
  final PackageUnit unit;
  final PackageSizeSource source;

  static PackageSize? tryCreate(
    num? quantity,
    PackageUnit? unit,
    PackageSizeSource? source,
  ) {
    if (quantity == null || unit == null || source == null) return null;
    final value = quantity.toDouble();
    if (!value.isFinite || value < minQuantity || value > maxQuantity) {
      return null;
    }
    return PackageSize._(value, unit, source);
  }

  /// Lê as colunas `package_*` de uma linha do banco. Produtos antigos (tudo
  /// null) ou linhas inválidas resultam em null, sem erro.
  static PackageSize? fromColumns({
    Object? quantity,
    Object? unit,
    Object? source,
  }) {
    final number = switch (quantity) {
      num n => n,
      String s => num.tryParse(s.trim()),
      _ => null,
    };
    return tryCreate(
      number,
      PackageUnit.fromSymbol(unit),
      PackageSizeSource.fromCode(source),
    );
  }

  PackageDimension get dimension => unit.dimension;

  /// Quantidade na base da grandeza: gramas para massa, mililitros para volume.
  double get baseQuantity => quantity * unit.baseFactor;

  bool isComparableTo(PackageSize other) => dimension == other.dimension;

  /// Quantidade expressa em [target]; null se a grandeza for diferente
  /// (nunca converte massa em volume).
  double? quantityIn(PackageUnit target) =>
      target.dimension == dimension ? baseQuantity / target.baseFactor : null;

  /// Texto para a interface, em pt-BR e na unidade mais legível:
  /// 500 g, 1 kg, 250 ml, 1,5 l.
  String get label {
    final base = baseQuantity;
    final shown = switch (dimension) {
      PackageDimension.mass => base >= 1000 ? PackageUnit.kg : PackageUnit.g,
      PackageDimension.volume => base >= 1000 ? PackageUnit.l : PackageUnit.ml,
    };
    return '${_formatNumber(base / shown.baseFactor)} ${shown.symbol}';
  }

  @override
  bool operator ==(Object other) =>
      other is PackageSize &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.source == source;

  @override
  int get hashCode => Object.hash(quantity, unit, source);

  @override
  String toString() => 'PackageSize($label, ${source.code})';
}

/// Preço (em centavos) por [per] (ex.: centavos por kg ou por l).
///
/// Devolve null — nunca um valor fictício — quando o preço é ausente, zero ou
/// negativo, quando o tamanho é desconhecido ou quando [per] é de outra
/// grandeza que a embalagem (massa x volume).
double? pricePerUnit({
  required int? priceCents,
  required PackageSize? size,
  required PackageUnit per,
}) {
  if (priceCents == null || priceCents <= 0 || size == null) return null;
  final quantity = size.quantityIn(per);
  if (quantity == null || quantity <= 0) return null;
  return priceCents / quantity;
}

String _formatNumber(double value) {
  final fixed = value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return fixed.replaceAll('.', ',');
}
