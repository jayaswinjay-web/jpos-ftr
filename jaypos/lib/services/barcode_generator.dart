import 'package:flutter_riverpod/flutter_riverpod.dart';

class BarcodeGenerator {
  Future<dynamic> generateCode128(String data) async {
    // Returns a barcode widget or raw data for printing
    return data;
  }

  Future<dynamic> generateQrCode(String data) async {
    // Returns a QR code widget or raw data for printing
    return data;
  }

  Future<void> printSticker({
    required String productName,
    required String sku,
    required String price,
    required String data,
    required String barcodeType,
    required String stickerSize,
    int quantity = 1,
  }) async {
    // Generate and send to printer
  }
}

final barcodeGeneratorProvider = Provider<BarcodeGenerator>((ref) {
  return BarcodeGenerator();
});
