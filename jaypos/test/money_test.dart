import 'package:flutter_test/flutter_test.dart';
import 'package:jaypos/core/utils/money.dart';

void main() {
  group('Money', () {
    test('creates from paise', () {
      final money = Money(100);
      expect(money.paise, 100);
      expect(money.rupees, 1.0);
    });

    test('creates from rupees', () {
      final money = Money.fromRupees(99.99);
      expect(money.paise, 9999);
    });

    test('formats correctly', () {
      expect(Money(100).format(), '₹1.00');
      expect(Money(1050).format(), '₹10.50');
      expect(Money(100000).format(), '₹1,000.00');
      expect(Money(10000000).format(), '₹1,00,000.00');
    });

    test('adds correctly', () {
      final a = Money(100);
      final b = Money(200);
      expect((a + b).paise, 300);
    });

    test('subtracts correctly', () {
      final a = Money(300);
      final b = Money(100);
      expect((a - b).paise, 200);
    });

    test('subtract clamps at zero', () {
      final a = Money(100);
      final b = Money(300);
      expect((a - b).paise, 0);
    });

    test('multiplies correctly', () {
      final money = Money(100);
      expect((money * 3).paise, 300);
    });

    test('calculates tax amount correctly', () {
      final money = Money(10000); // ₹100
      final tax = money.taxAmount(18.0); // 18% GST
      expect(tax.paise, 1800); // ₹18
    });

    test('tax inclusive backout works correctly', () {
      // ₹118 inclusive of 18% GST
      final inclusive = Money(11800);
      final base = inclusive.taxInclusiveBackout(18.0);
      // Base should be ₹100 = 10000 paise
      expect(base.paise, 10000);
    });

    test('tax exclusive add works correctly', () {
      final base = Money(10000); // ₹100
      final total = base.taxExclusiveAdd(18.0); // Add 18% GST
      expect(total.paise, 11800); // ₹118
    });

    test('percentage calculation', () {
      final money = Money(10000);
      final tenPercent = money.percentage(10.0);
      expect(tenPercent.paise, 1000);
    });

    test('comparison operators', () {
      expect(Money(100) < Money(200), true);
      expect(Money(200) > Money(100), true);
      expect(Money(100) <= Money(100), true);
      expect(Money(100) >= Money(100), true);
    });

    test('formatCompact works', () {
      expect(Money(100000).formatCompact(), '₹1.0K');
      expect(Money(10000000).formatCompact(), '₹1.00L');
      expect(Money(100000000).formatCompact(), '₹10.00L');
      expect(Money(1000000000).formatCompact(), '₹1.00Cr');
    });

    test('equality', () {
      expect(Money(100), Money(100));
      expect(Money(100) == Money(100), true);
      expect(Money(100) == Money(101), false);
    });

    test('tax inclusive and exclusive round-trip', () {
      // Base price ₹100
      final base = Money(10000);

      // Add 18% tax exclusively
      final withTax = base.taxExclusiveAdd(18.0);
      expect(withTax.paise, 11800);

      // Back out the tax from inclusive
      final backToBase = withTax.taxInclusiveBackout(18.0);
      expect(backToBase.paise, base.paise);
    });

    test('large numbers format with Indian grouping', () {
      expect(Money(123456789).format(), '₹12,34,567.89');
    });
  });
}
