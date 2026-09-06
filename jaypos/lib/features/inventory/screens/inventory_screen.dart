import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';
import '../../../services/scanner_service.dart';
import '../../../data/local/database.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _q = TextEditingController();
  final _nm = TextEditingController(), _sk = TextEditingController(), _bc = TextEditingController();
  final _sp = TextEditingController(), _pp = TextEditingController(), _st = TextEditingController(), _th = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _taxInclusive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scannerServiceProvider).onVolumeDown = () => _scanBarcode(context);
    });
  }

  void _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _results = []); return; }
    final db = ref.read(databaseProvider);
    final results = await db.searchProducts(q.trim());
    setState(() => _results = results);
  }

  void _scanBarcode(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(width: 300, height: 400, child: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull?.rawValue;
          if (barcode != null && mounted) {
            Navigator.pop(ctx);
            _q.text = barcode;
            _search(barcode);
          }
        },
      )),
    ));
  }

  void _scanBarcodeForAddForm(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(width: 300, height: 400, child: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull?.rawValue;
          if (barcode != null && mounted) {
            Navigator.pop(ctx);
            _bc.text = barcode;
            if (_sk.text.isEmpty) _sk.text = barcode;
          }
        },
      )),
    ));
  }

  @override void dispose() { ref.read(scannerServiceProvider).onVolumeDown = null; _q.dispose(); _nm.dispose(); _sk.dispose(); _bc.dispose(); _sp.dispose(); _pp.dispose(); _st.dispose(); _th.dispose(); super.dispose(); }

  void _addProduct() {
    _taxInclusive = false;
    String? _imagePath;
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Text('Add Product', style: Theme.of(ctx).textTheme.titleLarge), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
          const SizedBox(height: 16),
          Center(child: GestureDetector(onTap: () async {
            final img = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (img != null) setSheetState(() => _imagePath = img.path);
          }, child: Container(width: 120, height: 120,
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12),
              image: _imagePath != null ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover) : null),
            child: _imagePath == null ? const Icon(Icons.add_a_photo, size: 32, color: AppColors.onSurfaceVariant) : null))),
          const SizedBox(height: 12),
          TextField(controller: _nm, decoration: const InputDecoration(labelText: 'Product Name *')),
          const SizedBox(height: 12),
          TextField(controller: _sk, decoration: const InputDecoration(labelText: 'SKU *')),
          const SizedBox(height: 12),
          TextField(controller: _bc, decoration: InputDecoration(labelText: 'Barcode', suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _scanBarcodeForAddForm(ctx)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _sp, decoration: const InputDecoration(labelText: 'Sale Price (₹) *'), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _pp, decoration: const InputDecoration(labelText: 'Purchase Price (₹) *'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _st, decoration: const InputDecoration(labelText: 'Stock *'), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _th, decoration: const InputDecoration(labelText: 'Low Stock Alert'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Price includes tax'), value: _taxInclusive, onChanged: (v) => setSheetState(() => _taxInclusive = v)),
          const SizedBox(height: 8),
          SizedBox(height: 48, child: ElevatedButton(onPressed: () async {
            if (_nm.text.isEmpty || _sk.text.isEmpty || _sp.text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Required fields missing')));
              return;
            }
            final now = DateTime.now().toIso8601String();
            await ref.read(databaseProvider).insertProduct({
              'id': Uuid().v4(), 'name': _nm.text.trim(), 'sku': _sk.text.trim(),
              'barcode': _bc.text.isEmpty ? null : _bc.text.trim(),
              'category_id': null, 'purchase_price': ((double.tryParse(_pp.text) ?? 0) * 100).round(),
              'sale_price': ((double.tryParse(_sp.text) ?? 0) * 100).round(),
              'tax_rate': 0.0, 'tax_inclusive': _taxInclusive ? 1 : 0, 'stock': int.tryParse(_st.text) ?? 0,
              'low_stock_threshold': int.tryParse(_th.text) ?? 10,
              'image_path': _imagePath, 'supplier_id': null, 'description': null,
              'is_active': 1, 'created_at': now, 'updated_at': now,
            });
            _nm.clear(); _sk.clear(); _bc.clear(); _sp.clear(); _pp.clear(); _st.clear(); _th.clear();
            ref.invalidate(allProductsProvider);
            Navigator.pop(ctx);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added')));
          }, child: const Text('Add Product'))),
          const SizedBox(height: 24),
        ])));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final products = ref.watch(allProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _scanBarcode(context), tooltip: 'Scan barcode'),
          IconButton(icon: const Icon(Icons.download), onPressed: () async {
            final db = ref.read(databaseProvider);
            final products = await db.getAllProducts();
            if (!mounted) return;
            final csv = StringBuffer('Name,SKU,Barcode,Sale Price,Purchase Price,Stock,Low Stock Threshold\n');
            for (final p in products) {
              csv.writeln('${p['name']},${p['sku']},${p['barcode'] ?? ''},${p['sale_price']},${p['purchase_price']},${p['stock']},${p['low_stock_threshold']}');
            }
            final dir = await getTemporaryDirectory();
            final file = File('${dir.path}/products_export.csv');
            await file.writeAsString(csv.toString());
            await Share.shareXFiles([XFile(file.path)], text: 'Products CSV Export');
          }, tooltip: 'Export'),
          IconButton(icon: const Icon(Icons.upload), onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import: create a CSV with Name,SKU,Sale Price columns')));
          }, tooltip: 'Import'),
          PopupMenuButton(itemBuilder: (_) => [
            const PopupMenuItem(value: 'cat', child: Text('Categories')),
            const PopupMenuItem(value: 'adj', child: Text('Stock Adjustment')),
          ], onSelected: (v) {
            if (v == 'cat') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categories management coming soon')));
          }),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          controller: _q, decoration: InputDecoration(
            hintText: 'Search by name / SKU / barcode', prefixIcon: const Icon(Icons.search),
            suffixIcon: _q.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _q.clear(); setState(() => _results = []); }) : null,
          ), onChanged: _search,
        )),
        Expanded(
          child: _q.text.isNotEmpty
            ? (_results.isEmpty ? const Center(child: Text('No results')) : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _results.length,
                itemBuilder: (_, i) => _productCard(t, _results[i], context),
              ))
            : products.when(
                data: (list) => list.isEmpty
                  ? const Center(child: Text('No products. Add one!'))
                  : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: list.length, itemBuilder: (_, i) => _productCard(t, list[i], context)),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _addProduct, child: const Icon(Icons.add)),
    );
  }

  Widget _productCard(ThemeData t, Map<String, dynamic> p, BuildContext ctx) {
    final stock = p['stock'] as int? ?? 0;
    final low = p['low_stock_threshold'] as int? ?? 10;
    final isLow = stock <= low;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: InkWell(
      onTap: () => context.go('/inventory/product/${p['id']}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: isLow ? AppColors.dangerContainer : AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)),
          child: Icon(isLow ? Icons.warning_amber_rounded : Icons.inventory_2, color: isLow ? AppColors.danger : AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (isLow) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.dangerContainer, borderRadius: BorderRadius.circular(12)),
              child: const Text('Low', style: TextStyle(color: AppColors.danger, fontSize: 10))),
          ]),
          Text('SKU: ${p['sku']}', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(Money(p['sale_price'] as int).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
          Text('Stock: $stock', style: TextStyle(fontSize: 11, color: isLow ? AppColors.danger : null)),
        ]),
      ])),
    ));
  }
}
