import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';

final productDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return db.getProduct(id);
});

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final product = ref.watch(productDetailProvider(productId));

    return product.when(
      data: (p) => p == null
        ? Scaffold(appBar: AppBar(title: const Text('Product Detail')), body: const Center(child: Text('Product not found')))
        : Scaffold(
            appBar: AppBar(
              title: Text(p['name'] as String? ?? 'Product Detail'),
              actions: [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editProduct(context, ref, p)),
                PopupMenuButton(itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'print', child: Text('Print Sticker')),
                  const PopupMenuItem(value: 'adjust', child: Text('Adjust Stock')),
                  const PopupMenuItem(value: 'deactivate', child: Text('Delete Product')),
                ], onSelected: (v) async {
                  if (v == 'print') context.go('/inventory/sticker-print/${p['id']}');
                  if (v == 'adjust') context.go('/inventory/adjust/${p['id']}');
                  if (v == 'deactivate') {
                    final confirm = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
                      title: const Text('Delete Product'),
                      content: Text('Delete "${p['name']}"? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.pop(d, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete')),
                      ],
                    ));
                    if (confirm == true) {
                      await ref.read(databaseProvider).deleteProduct(p['id'] as String);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['name']} deleted')));
                        context.pop();
                      }
                    }
                  }
                }),
              ],
            ),
            body: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: GestureDetector(onTap: () => _editProduct(context, ref, p),
                child: Container(width: 200, height: 200,
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(AppRadius.lg),
                    image: p['image_path'] != null ? DecorationImage(image: FileImage(File(p['image_path'] as String)), fit: BoxFit.cover) : null),
                  child: p['image_path'] == null ? const Icon(Icons.add_a_photo, size: 40, color: AppColors.onSurfaceVariant) : null))),
              const SizedBox(height: AppSpacing.lg),
              Text(p['name'] as String? ?? '', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text('SKU: ${p['sku']}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Row(children: [
                Expanded(child: Column(children: [
                  Text('Sale Price', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(Money(p['sale_price'] as int).format(), style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.success)),
                ])),
                Container(width: 1, height: 40, color: theme.dividerColor),
                Expanded(child: Column(children: [
                  Text('Purchase Price', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(Money(p['purchase_price'] as int).format(), style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700)),
                ])),
                Container(width: 1, height: 40, color: theme.dividerColor),
                Expanded(child: Column(children: [
                  Text('Stock', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${p['stock']}', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700)),
                ])),
              ]))),
              const SizedBox(height: AppSpacing.md),
              Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Details', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _detailRow('Category', p['category_name'] as String? ?? 'N/A'),
                _detailRow('Barcode', p['barcode'] as String? ?? 'N/A'),
                _detailRow('Tax Rate', '${p['tax_rate'] ?? 0}% ${(p['tax_inclusive'] ?? 0) == 1 ? '(Inclusive)' : ''}'),
                _detailRow('Low Stock Threshold', '${p['low_stock_threshold'] ?? 10}'),
                _detailRow('Supplier', p['supplier_name'] as String? ?? 'N/A'),
              ]))),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => context.go('/inventory/sticker-print/${p['id']}'), icon: const Icon(Icons.qr_code), label: const Text('Print Sticker'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: OutlinedButton.icon(onPressed: () => context.go('/inventory/adjust/${p['id']}'), icon: const Icon(Icons.history), label: const Text('Stock History'))),
              ]),
            ])),
          ),
      loading: () => Scaffold(appBar: AppBar(title: const Text('Product Detail')), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Product Detail')), body: Center(child: Text('Error: $e'))),
    );
  }

  void _editProduct(BuildContext context, WidgetRef ref, Map<String, dynamic> p) {
    final nameC = TextEditingController(text: p['name'] as String? ?? '');
    final skuC = TextEditingController(text: p['sku'] as String? ?? '');
    final barcodeC = TextEditingController(text: p['barcode'] as String? ?? '');
    final spC = TextEditingController(text: '${(p['sale_price'] as int? ?? 0) / 100}');
    final ppC = TextEditingController(text: '${(p['purchase_price'] as int? ?? 0) / 100}');
    final stC = TextEditingController(text: '${p['stock'] ?? 0}');
    final thC = TextEditingController(text: '${p['low_stock_threshold'] ?? 10}');
    String? imagePath = p['image_path'] as String?;
    bool taxInclusive = (p['tax_inclusive'] ?? 0) == 1;

    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Text('Edit Product', style: Theme.of(ctx).textTheme.titleLarge), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
          const SizedBox(height: 16),
          Center(child: GestureDetector(onTap: () async {
            final img = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (img != null) setSheetState(() => imagePath = img.path);
          }, child: Container(width: 120, height: 120,
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12),
              image: imagePath != null ? DecorationImage(image: FileImage(File(imagePath!)), fit: BoxFit.cover) : null),
            child: imagePath == null ? const Icon(Icons.add_a_photo, size: 32, color: AppColors.onSurfaceVariant) : null))),
          const SizedBox(height: 12),
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Product Name *')),
          const SizedBox(height: 12),
          TextField(controller: skuC, decoration: const InputDecoration(labelText: 'SKU *')),
          const SizedBox(height: 12),
          TextField(controller: barcodeC, decoration: const InputDecoration(labelText: 'Barcode')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: spC, decoration: const InputDecoration(labelText: 'Sale Price (₹) *'), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: ppC, decoration: const InputDecoration(labelText: 'Purchase Price (₹) *'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: stC, decoration: const InputDecoration(labelText: 'Stock *'), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: thC, decoration: const InputDecoration(labelText: 'Low Stock Alert'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Price includes tax'), value: taxInclusive, onChanged: (v) => setSheetState(() => taxInclusive = v)),
          const SizedBox(height: 8),
          SizedBox(height: 48, child: ElevatedButton(onPressed: () async {
            if (nameC.text.isEmpty || skuC.text.isEmpty || spC.text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Required fields missing')));
              return;
            }
            final now = DateTime.now().toIso8601String();
            await ref.read(databaseProvider).updateProduct({
              'id': p['id'], 'name': nameC.text.trim(), 'sku': skuC.text.trim(),
              'barcode': barcodeC.text.isEmpty ? null : barcodeC.text.trim(),
              'category_id': p['category_id'], 'purchase_price': ((double.tryParse(ppC.text) ?? 0) * 100).round(),
              'sale_price': ((double.tryParse(spC.text) ?? 0) * 100).round(),
              'tax_rate': p['tax_rate'] ?? 0.0, 'tax_inclusive': taxInclusive ? 1 : 0,
              'stock': int.tryParse(stC.text) ?? 0, 'low_stock_threshold': int.tryParse(thC.text) ?? 10,
              'image_path': imagePath, 'supplier_id': p['supplier_id'],
              'description': p['description'], 'is_active': 1,
              'updated_at': now,
            });
            ref.invalidate(productDetailProvider(productId));
            ref.invalidate(allProductsProvider);
            Navigator.pop(ctx);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated')));
          }, child: const Text('Save'))),
          const SizedBox(height: 24),
        ])));
      }),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ]));
  }
}
