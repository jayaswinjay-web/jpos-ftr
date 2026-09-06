import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'product_detail_screen.dart';

class StickerPrintScreen extends ConsumerStatefulWidget {
  final String productId;
  const StickerPrintScreen({super.key, required this.productId});
  @override
  ConsumerState<StickerPrintScreen> createState() => _StickerPrintScreenState();
}

class _StickerPrintScreenState extends ConsumerState<StickerPrintScreen> {
  String _barcodeType = 'code128';
  String _size = '58x40';
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productDetailProvider(widget.productId));

    return product.when(
      data: (p) => p == null
        ? Scaffold(appBar: AppBar(title: const Text('Print Sticker')), body: const Center(child: Text('Product not found')))
        : Scaffold(
            appBar: AppBar(title: Text('${p['name']} - Sticker')),
            body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Column(children: [
                  if (_barcodeType == 'code128')
                    BarcodeWidget(barcode: Barcode.code128(), data: p['barcode'] as String? ?? (p['sku'] as String? ?? ''), width: _size.startsWith('38') ? 200 : 280, height: 60)
                  else
                    QrImageView(data: p['barcode'] as String? ?? (p['sku'] as String? ?? ''), size: 120, backgroundColor: Colors.white),
                  const SizedBox(height: 8),
                  Text(p['name'] as String, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                  Text('₹${((p['sale_price'] as int) / 100).toStringAsFixed(0)}', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
                ]),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Barcode Type'), value: _barcodeType,
                items: const [
                  DropdownMenuItem(value: 'code128', child: Text('Code128 Barcode')),
                  DropdownMenuItem(value: 'qr', child: Text('QR Code')),
                ],
                onChanged: (v) { if (v != null) setState(() => _barcodeType = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Sticker Size'), value: _size,
                items: const [
                  DropdownMenuItem(value: '38x25', child: Text('38 × 25 mm')),
                  DropdownMenuItem(value: '50x30', child: Text('50 × 30 mm')),
                  DropdownMenuItem(value: '58x40', child: Text('58 × 40 mm')),
                ],
                onChanged: (v) { if (v != null) setState(() => _size = v); },
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Quantity: '),
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: _qty > 1 ? () => setState(() => _qty--) : null),
                Text('$_qty', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _qty < 100 ? () => setState(() => _qty++) : null),
              ]),
              const SizedBox(height: 16),
              SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () async {
                final data = p['barcode'] as String? ?? (p['sku'] as String? ?? '');
                final name = p['name'] as String;
                final price = '₹${((p['sale_price'] as int) / 100).toStringAsFixed(0)}';
                await Printing.layoutPdf(onLayout: (_) async {
                  final doc = pw.Document();
                  for (int i = 0; i < _qty; i++) {
                    doc.addPage(pw.Page(build: (ctx) => pw.Column(children: [
                      pw.Text(data, style: pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 4),
                      pw.Text(name, style: pw.TextStyle(fontSize: 10)),
                      pw.Text(price, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ])));
                  }
                  return doc.save();
                });
              }, icon: const Icon(Icons.print), label: Text('Print $_qty Sticker(s)'))),
            ])),
          ),
      loading: () => Scaffold(appBar: AppBar(title: const Text('Print Sticker')), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Print Sticker')), body: Center(child: Text('Error: $e'))),
    );
  }
}
