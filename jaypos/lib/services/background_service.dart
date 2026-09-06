import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackgroundService {
  bool _isRunning = false;

  Future<void> start() async {
    _isRunning = true;
  }

  Future<void> stop() async {
    _isRunning = false;
  }

  Future<void> ensureOpenWARunning() async {
    // On Android: uses flutter_background_service to launch/kcep-alive OpenWA Node.js process
    // On Windows: launches OpenWA as a background Node.js process
  }

  bool get isRunning => _isRunning;
}

final backgroundServiceProvider = Provider<BackgroundService>((ref) {
  return BackgroundService();
});
