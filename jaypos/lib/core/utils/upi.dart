/// Ported from the `upi-pos` reference implementation
/// amounts are handled in paise everywhere and only
/// converted to rupees at the last moment
class Upi {
  const Upi._();

  /// Transaction reference embedded in the QR as `tn=`, used as the primary
  /// matching key against incoming payment notifications

  /// Format: `UPI<YYYYMMDD>-<NNNNNN>`
  /// [sequence] should be a per-day counter
  static String generateTxnRef({DateTime? at, required int sequence}) {
    final now = at ?? DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final seq = (sequence % 1000000).toString().padLeft(6, '0');
    return 'UPI$y$m$d-$seq';
  }

  /// Convenience: derives a sequence from the time of day (seconds since
  /// midnight + millisecond jitter), so refs stay unique per counter per day
  /// without needing a persisted counter
  static String generateTxnRefAuto({DateTime? at}) {
    final now = at ?? DateTime.now();
    final secondsToday = now.hour * 3600 + now.minute * 60 + now.second;
    return generateTxnRef(
        at: now, sequence: secondsToday * 10 + (now.millisecond ~/ 100),);
  }

  /// Builds the `upi://pay` URI rendered as the dynamic QR
  /// [amountPaise] is JayPOS-native paise; [txnRef] is the fingerprint the
  /// notification listener will look for
  static String buildPayString({
    required String upiId,
    required String payeeName,
    required int amountPaise,
    required String txnRef,
  }) {
    final amountRupees = (amountPaise / 100.0).toStringAsFixed(2);
    final params = <String, String>{
      'pa': upiId,
      'pn': payeeName,
      'am': amountRupees,
      'cu': 'INR', // currency
      'tn': txnRef, // transaction note
    };
    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
    return 'upi://pay?$query';
  }
}
