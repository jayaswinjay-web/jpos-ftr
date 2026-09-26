import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';

/// A UPI credit detected by the native notification listener.
class UpiPaymentEvent {
  const UpiPaymentEvent({
    required this.id,
    required this.amountPaise,
    required this.reference,
    required this.txnRef,
    required this.source,
  });

  factory UpiPaymentEvent.fromRow(Map<String, dynamic> row) => UpiPaymentEvent(
        id: row['id'] as int,
        amountPaise: row['amount'] as int,
        reference: (row['reference'] as String?) ?? '',
        txnRef: (row['txn_ref'] as String?) ?? '',
        source: (row['source'] as String?) ?? 'notification',
      );

  final int id;
  final int amountPaise;
  final String reference;
  final String txnRef;
  final String source;

}

/// Result of matching an event against the open orders.
class UpiMatch {
  const UpiMatch({required this.event, required this.transactionId});

  final UpiPaymentEvent event;
  final String transactionId;
}

/// Real-time UPI payment detection.
///
/// Mirrors the `upi-pos` reference design: the native
/// `UpiNotificationListener` writes detected credits into the shared SQLite
/// `upi_payment_events` table, and Dart **polls** that queue rather than using
/// an EventChannel — the listener process can fire while no Flutter engine is
/// attached, so the DB is the reliable handoff point.
///
/// Everything here works offline; Supabase sync happens separately, after the
/// local state has already been updated.
class UpiDetectionService {
  UpiDetectionService(this._db);

  static const MethodChannel _channel =
      MethodChannel('com.jaytech.jaypos/upi_detection');
  static const Duration pollInterval = Duration(seconds: 3);

  final AppDatabase _db;
  Timer? _timer;
  final _controller = StreamController<UpiMatch>.broadcast();

  /// Emits whenever a detected payment is matched to a pending order.
  Stream<UpiMatch> get matches => _controller.stream;

  bool get isRunning => _timer?.isActive ?? false;

  // ── Permission (platform channel) ───────────────────────────────────
  Future<bool> isNotificationAccessGranted() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('isNotificationAccessGranted');
      return granted ?? false;
    } on PlatformException {
      return false; // non-Android platform / channel unavailable
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationAccessSettings');
    } on PlatformException {
      // ignored — caller shows guidance instead
    } on MissingPluginException {
      // ignored
    }
  }

  // ── Detection lifecycle ─────────────────────────────────────────────
  void startDetection() {
    if (isRunning) return;
    _timer = Timer.periodic(pollInterval, (_) => _drainQueue());
    unawaited(_drainQueue()); // don't wait a full interval for the first pass
  }

  void stopDetection() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopDetection();
    unawaited(_controller.close());
  }

  /// Processes every queued event once, marking each as processed so it can
  /// never be applied to a second order.
  Future<void> _drainQueue() async {
    late final List<Map<String, dynamic>> rows;
    try {
      rows = await _db.getUnprocessedUpiPaymentEvents();
    } catch (_) {
      return; // DB busy — next tick retries
    }
    for (final row in rows) {
      final event = UpiPaymentEvent.fromRow(row);
      try {
        final txId = await _matchEvent(event);
        // Mark processed either way: an unmatched credit must not be replayed
        // against a future, unrelated order.
        await _db.markUpiPaymentEventProcessed(event.id);
        if (txId != null) {
          _controller.add(UpiMatch(event: event, transactionId: txId));
        }
      } catch (_) {
        // Leave unprocessed so the next tick retries this event.
      }
    }
  }

  /// Matching heuristics, in the reference project's priority order:
  ///   1. exact `txnRef` embedded in our QR (authoritative)
  ///   2. exact amount, only when exactly one pending order is open
  Future<String?> _matchEvent(UpiPaymentEvent event) async {
    if (event.txnRef.isNotEmpty) {
      final byRef = await _db.getPendingTransactionByTxnRef(event.txnRef);
      if (byRef != null) {
        return _markPaid(byRef['id'] as String, event);
      }
    }
    final byAmount =
        await _db.getSinglePendingTransactionByAmount(event.amountPaise);
    if (byAmount != null) {
      return _markPaid(byAmount['id'] as String, event);
    }
    return null;
  }

  Future<String> _markPaid(String txId, UpiPaymentEvent event) async {
    final reference = event.reference.isNotEmpty ? event.reference : event.txnRef;
    await _db.finalizePendingTransaction(
      txId,
      method: 'upi',
      reference: reference.isEmpty ? null : reference,
    );
    return txId;
  }
}

final upiDetectionServiceProvider = Provider<UpiDetectionService>((ref) {
  final service = UpiDetectionService(ref.watch(databaseProvider));
  ref.onDispose(service.dispose);
  return service;
});
