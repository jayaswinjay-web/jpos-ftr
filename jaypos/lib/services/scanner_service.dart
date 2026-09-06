import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class ScannerService {
  String? _lastScannedBarcode;
  DateTime _lastScanTime = DateTime.now().subtract(const Duration(seconds: 10));
  static const _cooldown = Duration(milliseconds: 1500);
  late final MethodChannel _channel;
  final _volumeDownController = StreamController<void>.broadcast();
  Stream<void> get volumeDownStream => _volumeDownController.stream;

  void Function()? onVolumeDown;

  ScannerService() {
    _channel = const MethodChannel('com.jaytech.jaypos/volume_scanner');
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeDownPressed') {
        _volumeDownController.add(null);
        onVolumeDown?.call();
      }
    });
  }

  void onBarcodeDetected(String barcode) {
    final now = DateTime.now();
    if (now.difference(_lastScanTime) < _cooldown) return;
    _lastScannedBarcode = barcode;
    _lastScanTime = now;
  }

  String? consumeScannedBarcode() {
    final code = _lastScannedBarcode;
    _lastScannedBarcode = null;
    return code;
  }

  void handleHidInput(String key) {}

  String? get lastScannedBarcode => _lastScannedBarcode;

  void dispose() {
    _volumeDownController.close();
  }
}

final scannerServiceProvider = Provider<ScannerService>((ref) {
  final service = ScannerService();
  ref.onDispose(() => service.dispose());
  return service;
});
