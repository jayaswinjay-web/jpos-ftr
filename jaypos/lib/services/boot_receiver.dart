import 'package:flutter_riverpod/flutter_riverpod.dart';

class BootReceiver {
  Future<void> onBootCompleted() async {
    // Android: broadcast receiver fires, app starts and initializes OpenWA
    // Windows: registry run key launches app on startup
  }

  Future<void> registerStartup() async {
    // Register the app to auto-start on boot
  }

  Future<void> unregisterStartup() async {
    // Remove from auto-start
  }
}

final bootReceiverProvider = Provider<BootReceiver>((ref) {
  return BootReceiver();
});
