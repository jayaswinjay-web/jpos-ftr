import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/di/providers.dart';
import '../../../data/local/database.dart';
import '../../billing/controllers/billing_controller.dart';

class ContinuousScanner extends ConsumerStatefulWidget {
  const ContinuousScanner({super.key});
  @override
  ConsumerState<ContinuousScanner> createState() => _ContinuousScannerState();
}

class _ContinuousScannerState extends ConsumerState<ContinuousScanner> {
  final AudioPlayer _player = AudioPlayer();
  DateTime _lastScan = DateTime.now();
  static const _cooldown = Duration(milliseconds: 300);

  void _beep() {
    _player.play(AssetSource('sounds/beep.wav'));
  }

  void _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;
    final now = DateTime.now();
    if (now.difference(_lastScan) < _cooldown) return;
    _lastScan = now;

    _beep();

    final db = ref.read(databaseProvider);
    final product = await db.searchProducts(barcode.trim());
    final match = product.isNotEmpty ? product.first : null;
    if (match != null && mounted) {
      ref.read(billingControllerProvider.notifier).addItem(match);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('+ ${match['name']}'),
          duration: const Duration(milliseconds: 600),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Fast Scan — scanning...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: MobileScanner(
        onDetect: _onDetect,
      ),
    );
  }
}
