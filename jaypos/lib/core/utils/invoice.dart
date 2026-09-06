import 'dart:math';

class InvoiceGenerator {
  static final Random _random = Random();

  static String generate() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final hexPart = List.generate(6, (_) => _random.nextInt(16).toRadixString(16)).join();
    return 'INV-$datePart-$hexPart';
  }
}
