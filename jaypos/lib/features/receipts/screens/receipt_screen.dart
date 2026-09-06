import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';
import '../../../services/openwa_service.dart';

final fullTxProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final db = ref.watch(databaseProvider);
  final tx = await db.getTransaction(id);
  if (tx == null) return null;
  final items = await db.getTransactionItems(id);
  final payments = await db.getTransactionPayments(id);
  tx['items'] = items;
  tx['payments'] = payments;
  return tx;
});

class ReceiptScreen extends ConsumerWidget {
  final String txId;
  const ReceiptScreen({super.key, required this.txId});

  Future<pw.Document> _buildPdf(Map<String, dynamic> tx, Map<String, String> settings, Map<String, String> tmpl) async {
    final doc = pw.Document();
    final invoiceNo = tx['invoice_no'] as String;
    final storeName = settings['store_name'] ?? 'My Store';
    final storeAddr = settings['store_address'] ?? '';
    final header = tmpl['receipt_header'] ?? 'JayPOS';
    final footer = tmpl['receipt_footer'] ?? 'Thank you! Visit again!';
    final fontSize = double.tryParse(tmpl['receipt_font_size'] ?? '13') ?? 13;
    final showLogo = tmpl['receipt_show_logo'] != '0';
    final showAddr = tmpl['receipt_show_address'] != '0';
    final showGst = tmpl['receipt_show_gst'] != '0';
    final showBarcode = tmpl['receipt_show_barcode'] != '0';
    final showPayment = tmpl['receipt_show_payment'] != '0';

    doc.addPage(pw.Page(build: (ctx) {
      final items = (tx['items'] as List?) ?? [];
      final itemRows = items.map((it) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${it['product_name']} x${it['quantity']}', style: pw.TextStyle(fontSize: fontSize - 2)),
        pw.Text(Money(it['line_total'] as int).format(), style: pw.TextStyle(fontSize: fontSize - 2)),
      ])).toList();

      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (showLogo) pw.Center(child: pw.Text(storeName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
        if (showAddr && storeAddr.isNotEmpty) pw.Center(child: pw.Text(storeAddr, style: pw.TextStyle(fontSize: 8))),
        pw.Center(child: pw.Text(header, style: pw.TextStyle(fontSize: fontSize - 2))),
        pw.Center(child: pw.Text('Invoice: $invoiceNo', style: pw.TextStyle(fontSize: fontSize))),
        pw.Text('Date: ${(tx['created_at'] as String?)?.substring(0, 10) ?? ''}', style: pw.TextStyle(fontSize: fontSize - 2)),
        pw.Divider(thickness: 0.5),
        ...itemRows,
        if (showGst) ...[
          pw.Divider(thickness: 0.5),
          _pdfRow('Subtotal', Money(tx['subtotal'] as int).format(), fontSize - 2),
          if ((tx['discount_amount'] as int? ?? 0) > 0) _pdfRow('Discount', '-${Money(tx['discount_amount'] as int).format()}', fontSize - 2),
          _pdfRow('Tax', Money(tx['tax_amount'] as int).format(), fontSize - 2),
          if ((tx['round_off'] as int? ?? 0) != 0) _pdfRow('Round Off', Money(tx['round_off'] as int).format(), fontSize - 2),
        ],
        pw.Divider(thickness: 0.5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize + 2)),
          pw.Text(Money(tx['total'] as int).format(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize + 2)),
        ]),
        if (showPayment && tx['payments'] != null) ...((tx['payments'] as List).map((p) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Paid via ${(p['method'] as String).toUpperCase()}', style: pw.TextStyle(fontSize: fontSize - 4)),
          pw.Text(Money(p['amount'] as int).format(), style: pw.TextStyle(fontSize: fontSize - 4)),
        ]))),
        pw.SizedBox(height: 12),
        pw.Center(child: pw.Text(footer, style: pw.TextStyle(fontSize: fontSize - 2, fontStyle: pw.FontStyle.italic))),
        if (showBarcode) ...[
          pw.SizedBox(height: 12),
          pw.Center(child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: invoiceNo, width: 80, height: 80)),
          pw.Center(child: pw.Text(invoiceNo, style: pw.TextStyle(fontSize: 7))),
        ],
      ]);
    }));
    return doc;
  }

  pw.Widget _pdfRow(String label, String value, double size) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: size)),
      pw.Text(value, style: pw.TextStyle(fontSize: size)),
    ]);
  }

  Future<void> _sharePdf(BuildContext context, Map<String, dynamic> tx, Map<String, String> settings, Map<String, String> tmpl) async {
    final pdf = await _buildPdf(tx, settings, tmpl);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_${tx['invoice_no']}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Receipt ${tx['invoice_no']}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tx = ref.watch(fullTxProvider(txId));
    final settings = ref.watch(settingsProvider).valueOrNull ?? {};

    return tx.when(
      data: (d) => d == null
        ? Scaffold(appBar: AppBar(title: const Text('Receipt')), body: const Center(child: Text('Not found')))
        : Scaffold(
            appBar: AppBar(title: Text('Receipt ${d['invoice_no']}'), actions: [
              IconButton(icon: const Icon(Icons.share), onPressed: () => _sharePdf(context, d, settings, settings)),
              IconButton(icon: const Icon(Icons.print), onPressed: () async {
                final pdf = await _buildPdf(d, settings, settings);
                await Printing.layoutPdf(onLayout: (_) => pdf.save());
              }),
              IconButton(icon: Icon(Icons.chat, color: AppColors.success), tooltip: 'WhatsApp', onPressed: () async {
                final wa = ref.read(openwaServiceProvider);
                final phone = d['customer_phone'] as String?;
                final header = settings['receipt_header'] ?? 'JayPOS';
                final footer = settings['receipt_footer'] ?? 'Thank you! Visit again!';
                final msg = '$header\nInvoice: ${d['invoice_no']}\nTotal: ${Money(d['total'] as int).format()}\n$footer';
                if (phone != null && phone.isNotEmpty) {
                  final sent = await wa.sendMessage(phone: phone, message: msg);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sent ? 'Receipt sent via WhatsApp' : 'WhatsApp send failed'), backgroundColor: sent ? AppColors.success : AppColors.danger));
                } else {
                  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }),
            ]),
            body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildReceiptView(theme, d, settings)),
          ),
      loading: () => Scaffold(appBar: AppBar(title: const Text('Receipt')), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Receipt')), body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildReceiptView(ThemeData theme, Map<String, dynamic> d, Map<String, String> s) {
    final items = (d['items'] as List?) ?? [];
    final storeName = s['store_name'] ?? 'My Store';
    final storeAddr = s['store_address'] ?? '';
    final header = s['receipt_header'] ?? 'JayPOS';
    final footer = s['receipt_footer'] ?? 'Thank you! Visit again!';
    final fontSize = double.tryParse(s['receipt_font_size'] ?? '13') ?? 13;
    final showLogo = s['receipt_show_logo'] != '0';
    final showAddr = s['receipt_show_address'] != '0';
    final showGst = s['receipt_show_gst'] != '0';
    final showBarcode = s['receipt_show_barcode'] != '0';
    final showPayment = s['receipt_show_payment'] != '0';

    return Column(children: [
      if (showLogo) Text(storeName, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
      if (showAddr && storeAddr.isNotEmpty) Text(storeAddr, style: GoogleFonts.inter(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 4),
      Text(header, style: GoogleFonts.inter(fontSize: fontSize - 4, color: AppColors.primary)),
      Text(d['invoice_no'] as String, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700)),
      Text((d['created_at'] as String?)?.substring(0, 19) ?? '', style: GoogleFonts.inter(fontSize: 10)),
      const Divider(height: 16),
      ...items.map((it) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
        Expanded(child: Text('${it['product_name']} x${it['quantity']}', style: GoogleFonts.inter(fontSize: fontSize))),
        Text(Money(it['line_total'] as int).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: fontSize)),
      ]))),
      const Divider(height: 16),
      if (showGst) ...[
        _r('Subtotal', Money(d['subtotal'] as int).format(), fontSize - 1),
        if ((d['discount_amount'] as int? ?? 0) > 0) _r('Discount', '-${Money(d['discount_amount'] as int).format()}', fontSize - 1, AppColors.danger),
        _r('Tax', Money(d['tax_amount'] as int).format(), fontSize - 1),
        if ((d['round_off'] as int? ?? 0) != 0) _r('Round Off', Money(d['round_off'] as int).format(), fontSize - 1),
      ],
      const Divider(thickness: 1.5),
      _r('Total', Money(d['total'] as int).format(), fontSize + 4, null, true),
      const SizedBox(height: 8),
      if (showPayment && d['payments'] != null) ...((d['payments'] as List).map((p) => _r(
        'Paid via ${(p['method'] as String).toUpperCase()}', Money(p['amount'] as int).format(), fontSize - 3,
      ))),
      const SizedBox(height: 12),
      Text(footer, style: GoogleFonts.inter(fontSize: fontSize - 2, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant)),
      if (showBarcode) ...[
        const SizedBox(height: 12),
        Center(child: QrImageView(data: d['invoice_no'] as String, version: QrVersions.auto, size: 100, backgroundColor: Colors.white)),
        const SizedBox(height: 4),
        Text(d['invoice_no'] as String, style: GoogleFonts.spaceGrotesk(fontSize: 10, letterSpacing: 1)),
      ],
    ]);
  }

  Widget _r(String label, String value, double size, [Color? color, bool bold = false]) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.inter(fontSize: size, fontWeight: bold ? FontWeight.bold : null, color: color)),
      Text(value, style: GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color)),
    ]));
  }
}
