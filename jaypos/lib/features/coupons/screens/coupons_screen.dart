import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';

final allCouponsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(databaseProvider).getCoupons();
});

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});
  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final _codeC = TextEditingController();
  String _discountType = 'flat';
  final _valueC = TextEditingController();
  final _minC = TextEditingController();
  final _maxC = TextEditingController();
  final _expiryC = TextEditingController();

  @override
  void dispose() {
    _codeC.dispose(); _valueC.dispose(); _minC.dispose(); _maxC.dispose(); _expiryC.dispose();
    super.dispose();
  }

  void _showCreateSheet() {
    _codeC.clear(); _valueC.clear(); _minC.clear(); _maxC.clear(); _expiryC.clear();
    _discountType = 'flat';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Text('Create Coupon', style: Theme.of(ctx).textTheme.titleLarge), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
            const SizedBox(height: 16),
            TextField(controller: _codeC, decoration: InputDecoration(labelText: 'Coupon Code *', hintText: 'e.g. SAVE20', prefixStyle: GoogleFonts.spaceGrotesk())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Discount Type'),
              value: _discountType,
              items: const [
                DropdownMenuItem(value: 'flat', child: Text('Flat ₹')),
                DropdownMenuItem(value: 'percent', child: Text('Percentage %')),
              ],
              onChanged: (v) { if (v != null) setSheetState(() => _discountType = v); },
            ),
            const SizedBox(height: 12),
            TextField(controller: _valueC, decoration: InputDecoration(labelText: _discountType == 'flat' ? 'Discount (₹)' : 'Discount (%)'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _minC, decoration: const InputDecoration(labelText: 'Min Bill (₹)'), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _maxC, decoration: const InputDecoration(labelText: 'Max Uses (0=∞)'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _expiryC, decoration: const InputDecoration(labelText: 'Expiry (YYYY-MM-DD)', hintText: 'e.g. 2026-12-31')),
            const SizedBox(height: 16),
            SizedBox(height: 48, child: ElevatedButton(onPressed: () async {
              if (_codeC.text.trim().isEmpty || _valueC.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Code and discount value required')));
                return;
              }
              final now = DateTime.now().toIso8601String();
              await ref.read(databaseProvider).insertCoupon({
                'id': Uuid().v4(), 'code': _codeC.text.trim().toUpperCase(),
                'discount_type': _discountType, 'discount_value': ((double.tryParse(_valueC.text) ?? 0) * (_discountType == 'percent' ? 1 : 100)).round(),
                'min_bill_amount': ((double.tryParse(_minC.text) ?? 0) * 100).round(),
                'max_usage_count': int.tryParse(_maxC.text) ?? 0,
                'is_active': 1, 'expiry_date': _expiryC.text.trim().isEmpty ? null : _expiryC.text.trim(),
                'created_at': now,
              });
              ref.invalidate(allCouponsProvider);
              Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon created')));
            }, child: const Text('Create Coupon'))),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Future<void> _printBarcode(Map<String, dynamic> coupon) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.SizedBox(height: 40),
      pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: coupon['code'] as String, width: 260, height: 60),
      pw.SizedBox(height: 12),
      pw.Text(coupon['code'] as String, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Text(coupon['discount_type'] == 'flat'
        ? '${Money(coupon['discount_value'] as int).format()} OFF'
        : '${coupon['discount_value']}% OFF',
        style: pw.TextStyle(fontSize: 14)),
      if ((coupon['min_bill_amount'] as int? ?? 0) > 0) pw.Text('Min bill: ${Money(coupon['min_bill_amount'] as int).format()}', style: pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 4),
      pw.Text('Valid till: ${coupon['expiry_date'] ?? 'No expiry'}', style: pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 20),
      pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: coupon['code'] as String, width: 80, height: 80),
    ])));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  void _showCouponDetail(Map<String, dynamic> coupon) {
    showDialog(context: context, builder: (d) => AlertDialog(
      title: Text('${coupon['code']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        QrImageView(data: coupon['code'] as String, version: QrVersions.auto, size: 200),
        const SizedBox(height: 8),
        Text(coupon['code'] as String, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(coupon['discount_type'] == 'flat'
          ? '${Money(coupon['discount_value'] as int).format()} OFF'
          : '${coupon['discount_value']}% OFF',
          style: const TextStyle(fontSize: 14)),
        if ((coupon['min_bill_amount'] as int? ?? 0) > 0) Text('Min bill: ${Money(coupon['min_bill_amount'] as int).format()}', style: const TextStyle(fontSize: 12)),
        Text('Valid till: ${coupon['expiry_date'] ?? 'No expiry'}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        Text('Show this QR or barcode at checkout', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close')),
        ElevatedButton.icon(onPressed: () { Navigator.pop(d); _printBarcode(coupon); }, icon: const Icon(Icons.print, size: 18), label: const Text('Print Barcode')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final coupons = ref.watch(allCouponsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Create Coupon'),
      ),
      body: coupons.when(
        data: (list) => list.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.card_giftcard, size: 64, color: AppColors.onSurfaceVariant),
              const SizedBox(height: 12),
              const Text('No coupons yet', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Tap the button below to create one', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _showCreateSheet, icon: const Icon(Icons.add), label: const Text('Create Coupon')),
            ]))
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (_, i) => _couponCard(t, list[i])),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _couponCard(ThemeData t, Map<String, dynamic> c) {
    final isExpired = c['expiry_date'] != null && DateTime.tryParse(c['expiry_date']!)?.isBefore(DateTime.now()) == true;
    final isActive = c['is_active'] == 1 && !isExpired;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      InkWell(
        onTap: () => _showCouponDetail(c),
        borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: isActive ? AppColors.successContainer : AppColors.dangerContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(isActive ? Icons.card_giftcard : Icons.cancel, color: isActive ? AppColors.success : AppColors.danger)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(c['code'] as String, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 14)),
              if (!isActive) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.dangerContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(isExpired ? 'Expired' : 'Inactive', style: const TextStyle(color: AppColors.danger, fontSize: 10))),
            ]),
            Text(c['discount_type'] == 'flat' ? '${Money(c['discount_value'] as int).format()} OFF' : '${c['discount_value']}% OFF',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${c['used_count'] ?? 0}/${c['max_usage_count'] > 0 ? c['max_usage_count'] : '∞'}', style: const TextStyle(fontSize: 11)),
            if ((c['min_bill_amount'] as int? ?? 0) > 0) Text('Min ₹${(c['min_bill_amount'] as int) / 100}', style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.qr_code, size: 20, color: AppColors.primary),
        ]),
      ),
      const Divider(height: 12),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () => _printBarcode(c),
        icon: const Icon(Icons.print, size: 16),
        label: const Text('Print Barcode'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
      )),
    ])));
  }
}
