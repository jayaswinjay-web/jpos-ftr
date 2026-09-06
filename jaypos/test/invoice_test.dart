import 'package:flutter_test/flutter_test.dart';
import 'package:jaypos/core/utils/invoice.dart';

void main() {
  group('InvoiceGenerator', () {
    test('generates invoice with correct format', () {
      final invoice = InvoiceGenerator.generate();
      expect(invoice, startsWith('INV-'));
      expect(invoice.length, equals(19));

      final parts = invoice.split('-');
      expect(parts.length, 3);
      expect(parts[0], 'INV');
      expect(parts[1].length, 8); // YYYYMMDD
      expect(parts[2].length, 6); // 6 hex chars
    });

    test('generates unique invoices', () {
      final invoices = List.generate(100, (_) => InvoiceGenerator.generate());
      final unique = invoices.toSet();
      expect(unique.length, 100);
    });

    test('date part is valid date', () {
      final invoice = InvoiceGenerator.generate();
      final parts = invoice.split('-');
      final dateStr = parts[1];
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));

      expect(year, greaterThanOrEqualTo(2024));
      expect(month, inInclusiveRange(1, 12));
      expect(day, inInclusiveRange(1, 31));
    });
  });
}
