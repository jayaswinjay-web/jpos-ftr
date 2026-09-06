import 'package:equatable/equatable.dart';

class Money extends Equatable {
  final int paise;

  const Money(this.paise) : assert(paise >= 0);

  factory Money.fromRupees(double rupees) {
    return Money((rupees * 100).round());
  }

  factory Money.fromInt(int paise) {
    return Money(paise);
  }

  double get rupees => paise / 100.0;

  Money operator +(Money other) => Money(paise + other.paise);

  Money operator -(Money other) => Money((paise - other.paise).clamp(0, paise));

  Money operator *(int factor) => Money(paise * factor);

  Money operator %(Money other) {
    if (other.paise == 0) return Money(0);
    return Money(paise % other.paise);
  }

  Money percentage(double percent) {
    return Money((paise * percent / 100).round());
  }

  Money taxAmount(double taxRate) {
    return Money((paise * taxRate / 100).round());
  }

  Money taxInclusiveBackout(double taxRate) {
    final divisor = 100 + taxRate;
    final basePaise = (paise * 100 / divisor).round();
    return Money(basePaise);
  }

  Money taxExclusiveAdd(double taxRate) {
    return Money(paise + (paise * taxRate / 100).round());
  }

  bool operator <(Money other) => paise < other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  String format({String symbol = '₹', bool showDecimal = true}) {
    final whole = paise ~/ 100;
    final fraction = paise % 100;
    final formattedWhole = _addThousandSeparators(whole.toString());
    if (showDecimal) {
      return '$symbol$formattedWhole.${fraction.toString().padLeft(2, '0')}';
    }
    return '$symbol$formattedWhole';
  }

  String formatCompact() {
    final total = paise / 100.0;
    if (total >= 10000000) {
      return '₹${(total / 10000000).toStringAsFixed(2)}Cr';
    } else if (total >= 100000) {
      return '₹${(total / 100000).toStringAsFixed(2)}L';
    } else if (total >= 1000) {
      return '₹${(total / 1000).toStringAsFixed(1)}K';
    }
    return format();
  }

  static String _addThousandSeparators(String number) {
    if (number.length <= 3) return number;
    final lastThree = number.substring(number.length - 3);
    final rest = number.substring(0, number.length - 3);
    final withCommas = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        withCommas.write(',');
      }
      withCommas.write(rest[i]);
    }
    return '$withCommas,$lastThree';
  }

  Money copyWith({int? paise}) => Money(paise ?? this.paise);

  @override
  List<Object?> get props => [paise];

  @override
  String toString() => format();
}
