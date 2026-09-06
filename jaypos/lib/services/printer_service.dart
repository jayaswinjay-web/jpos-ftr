import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterService {
  bool _isConnected = false;
  String? _deviceAddress;
  String _deviceName = '';

  Future<List<Map<String, String>>> scanBluetoothPrinters() async {
    try {
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      return paired.map((b) => {'name': b.name, 'address': b.macAdress}).toList();
    } catch (e) {
      dev.log('Bluetooth scan error: $e');
      return [];
    }
  }

  Future<bool> connect(String address, {String name = ''}) async {
    try {
      final result = await PrintBluetoothThermal.connect(macPrinterAddress: address);
      if (result) {
        _deviceAddress = address;
        _deviceName = name;
        _isConnected = true;
        dev.log('Printer connected: $_deviceName ($address)');
        return true;
      }
      return false;
    } catch (e) {
      dev.log('Printer connect error: $e');
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      _deviceAddress = null;
      _deviceName = '';
      return true;
    } catch (e) {
      dev.log('Printer disconnect error: $e');
      return false;
    }
  }

  Future<void> printText(String text, {int width = 58}) async {
    if (!_isConnected) throw Exception('Printer not connected');
    var bytes = <int>[];
    for (final line in text.split('\n')) {
      bytes += _textLine(line);
    }
    bytes += _cut();
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printReceipt({
    required String storeName,
    required String invoiceNo,
    required List<Map<String, dynamic>> items,
    required String total,
    required String tax,
    required String paymentMethod,
    String? upiQrCode,
    String? customerPhone,
    String? footer,
    int width = 58,
  }) async {
    if (!_isConnected) throw Exception('Printer not connected');

    var bytes = <int>[];
    final sep = width == 80 ? 32 : 24;
    final divider = List.filled(sep, '=').join();
    final dashDivider = List.filled(sep, '-').join();

    bytes += _textLine(storeName, center: true, bold: true, size: 2);
    bytes += _textLine(divider, center: true);
    bytes += _textLine('Invoice: $invoiceNo', center: true);
    bytes += _textLine(dashDivider, center: true);

    for (final item in items) {
      final name = item['name'] as String? ?? '';
      final qty = item['qty'] ?? 1;
      final price = item['price'] ?? 0;
      bytes += _textLine(name.length > 16 ? '${name.substring(0, 16)}..' : name);
      bytes += _textLine('  $qty x $price');
    }

    bytes += _textLine(dashDivider, center: true);
    bytes += _textLine('Total: $total', bold: true, alignRight: true);
    bytes += _textLine('Tax: $tax', alignRight: true);
    bytes += _textLine('Payment: $paymentMethod', alignRight: true);
    bytes += _textLine(divider, center: true);
    bytes += _textLine(footer ?? 'Thank you!', center: true);
    bytes += _cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<bool> testPrint() async {
    if (!_isConnected) return false;
    try {
      var bytes = <int>[];
      bytes += _textLine('JayPOS', center: true, bold: true, size: 2);
      bytes += _textLine('Test Print', center: true);
      bytes += _textLine('============', center: true);
      bytes += _textLine('If you can read this,', center: true);
      bytes += _textLine('your printer is working!', center: true);
      bytes += _textLine('Thank you!', center: true);
      bytes += _cut();
      await PrintBluetoothThermal.writeBytes(bytes);
      return true;
    } catch (e) {
      dev.log('Test print error: $e');
      return false;
    }
  }

  List<int> _textLine(String text, {bool center = false, bool bold = false, int size = 1, bool alignRight = false}) {
    var bytes = <int>[];
    if (bold) bytes += _esc([0x45, 0x01]);
    if (size > 1) bytes += _esc([0x21, size == 2 ? 0x10 : 0x30]);
    if (center) bytes += _esc([0x61, 0x01]);
    else if (alignRight) bytes += _esc([0x61, 0x02]);
    else bytes += _esc([0x61, 0x00]);

    bytes += text.codeUnits;
    bytes += [0x0A];

    if (bold) bytes += _esc([0x45, 0x00]);
    if (size > 1) bytes += _esc([0x21, 0x00]);
    bytes += _esc([0x61, 0x00]);
    return bytes;
  }

  List<int> _esc(List<int> cmd) => [0x1B, ...cmd];

  List<int> _cut() => [0x1D, 0x56, 0x00];

  bool get isConnected => _isConnected;
  String? get deviceAddress => _deviceAddress;
  String get deviceName => _deviceName;
}

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});
