import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';

class ReceiptTemplateScreen extends ConsumerStatefulWidget {
  const ReceiptTemplateScreen({super.key});
  @override
  ConsumerState<ReceiptTemplateScreen> createState() => _ReceiptTemplateScreenState();
}

class _ReceiptTemplateScreenState extends ConsumerState<ReceiptTemplateScreen> {
  late TextEditingController _headerC;
  late TextEditingController _footerC;
  double _fontSize = 13;
  bool _showLogo = true;
  bool _showAddress = true;
  bool _showBarcode = true;
  bool _showGst = true;
  bool _showPayment = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _headerC = TextEditingController(text: 'JayPOS');
    _footerC = TextEditingController(text: 'Thank you! Visit again!');
  }

  @override
  void dispose() {
    _headerC.dispose();
    _footerC.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.setSetting('receipt_header', _headerC.text.trim());
    await db.setSetting('receipt_footer', _footerC.text.trim());
    await db.setSetting('receipt_font_size', _fontSize.toInt().toString());
    await db.setSetting('receipt_show_logo', _showLogo ? '1' : '0');
    await db.setSetting('receipt_show_address', _showAddress ? '1' : '0');
    await db.setSetting('receipt_show_barcode', _showBarcode ? '1' : '0');
    await db.setSetting('receipt_show_gst', _showGst ? '1' : '0');
    await db.setSetting('receipt_show_payment', _showPayment ? '1' : '0');
    ref.invalidate(settingsProvider);
    setState(() => _saving = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt template saved'), backgroundColor: AppColors.success),
    );
  }

  Map<String, dynamic> _demoTx() => {
    'invoice_no': 'DEMO-0001',
    'created_at': DateTime.now().toIso8601String(),
    'subtotal': 10000,
    'discount_amount': 200,
    'tax_amount': 1800,
    'round_off': 0,
    'total': 11600,
    'customer_phone': null,
    'items': [{'product_name': 'Demo Product', 'quantity': 2, 'line_total': 10000}],
    'payments': [{'method': 'cash', 'amount': 11600}],
    'notes': 'Demo transaction',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull ?? {};
    final settingsMap = settings is Map<String, String> ? settings : <String, String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Template'),
        actions: [
          TextButton.icon(onPressed: _saving ? null : _saveTemplate, icon: const Icon(Icons.save), label: const Text('Save')),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Template Options', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(controller: _headerC, decoration: const InputDecoration(labelText: 'Header Text', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)), maxLines: 2),
            const SizedBox(height: 8),
            TextField(controller: _footerC, decoration: const InputDecoration(labelText: 'Footer Text', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)), maxLines: 2),
            const SizedBox(height: 8),
            Row(children: [
              Text('Font Size: ${_fontSize.toInt()}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(child: Slider(value: _fontSize, min: 10, max: 18, divisions: 8, label: _fontSize.toInt().toString(), onChanged: (v) => setState(() => _fontSize = v))),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              FilterChip(label: const Text('Logo/Store Name'), selected: _showLogo, onSelected: (v) => setState(() => _showLogo = v)),
              FilterChip(label: const Text('Address'), selected: _showAddress, onSelected: (v) => setState(() => _showAddress = v)),
              FilterChip(label: const Text('GST/Tax'), selected: _showGst, onSelected: (v) => setState(() => _showGst = v)),
              FilterChip(label: const Text('Barcode'), selected: _showBarcode, onSelected: (v) => setState(() => _showBarcode = v)),
              FilterChip(label: const Text('Payment'), selected: _showPayment, onSelected: (v) => setState(() => _showPayment = v)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Text('Preview', style: theme.textTheme.titleSmall),
          const Spacer(),
          if (_saving) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: _buildPreview(theme, _demoTx(), settingsMap),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _saving ? null : _saveTemplate,
          icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
          label: const Text('Save Template'),
        )),
        const SizedBox(height: 16),
      ])),
    );
  }

  Widget _buildPreview(ThemeData theme, Map<String, dynamic> d, Map<String, String> settings) {
    final items = (d['items'] as List?) ?? [];
    final storeName = settings['store_name'] ?? 'My Store';
    final storeAddr = settings['store_address'] ?? '';

    return Column(children: [
      if (_showLogo) Text(storeName, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
      if (_showAddress && storeAddr.isNotEmpty) Text(storeAddr, style: GoogleFonts.inter(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 4),
      Text(_headerC.text, style: GoogleFonts.inter(fontSize: _fontSize - 4, color: AppColors.primary)),
      Text(d['invoice_no'] as String, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700)),
      Text((d['created_at'] as String?)?.substring(0, 19) ?? '', style: GoogleFonts.inter(fontSize: 10)),
      const Divider(height: 16),
      ...items.map((it) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
        Expanded(child: Text('${it['product_name']} x${it['quantity']}', style: GoogleFonts.inter(fontSize: _fontSize))),
        Text(Money(it['line_total'] as int).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: _fontSize)),
      ]))),
      const Divider(height: 16),
      if (_showGst) ...[
        _row('Subtotal', Money(d['subtotal'] as int).format(), _fontSize - 1),
        if ((d['discount_amount'] as int? ?? 0) > 0) _row('Discount', '-${Money(d['discount_amount'] as int).format()}', _fontSize - 1, AppColors.danger),
        _row('Tax', Money(d['tax_amount'] as int).format(), _fontSize - 1),
        if ((d['round_off'] as int? ?? 0) != 0) _row('Round Off', Money(d['round_off'] as int).format(), _fontSize - 1),
      ],
      const Divider(thickness: 1.5),
      _row('Total', Money(d['total'] as int).format(), _fontSize + 4, null, true),
      const SizedBox(height: 8),
      if (_showPayment && d['payments'] != null) ...((d['payments'] as List).map((p) => _row(
        'Paid via ${(p['method'] as String).toUpperCase()}', Money(p['amount'] as int).format(), _fontSize - 3,
      ))),
      const SizedBox(height: 12),
      Text(_footerC.text, style: GoogleFonts.inter(fontSize: _fontSize - 2, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant)),
      if (_showBarcode) ...[
        const SizedBox(height: 12),
        Center(child: QrImageView(data: d['invoice_no'] as String, version: QrVersions.auto, size: 100, backgroundColor: Colors.white)),
        const SizedBox(height: 4),
        Text(d['invoice_no'] as String, style: GoogleFonts.spaceGrotesk(fontSize: 10, letterSpacing: 1)),
      ],
    ]);
  }

  Widget _row(String label, String value, double size, [Color? color, bool bold = false]) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.inter(fontSize: size, fontWeight: bold ? FontWeight.bold : null, color: color)),
      Text(value, style: GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color)),
    ]));
  }
}
