import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../auth/controllers/auth_controller.dart';
import 'product_detail_screen.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final String productId;
  const StockAdjustmentScreen({super.key, required this.productId});
  @override
  ConsumerState<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _qtyC = TextEditingController();
  final _reasonC = TextEditingController();
  final _notesC = TextEditingController();
  String _reason = 'stock_in';

  @override
  void dispose() { _qtyC.dispose(); _reasonC.dispose(); _notesC.dispose(); super.dispose(); }

  void _save() async {
    final qty = int.tryParse(_qtyC.text) ?? 0;
    if (qty == 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter quantity'))); return; }
    final userId = ref.read(authControllerProvider).userId ?? 'system';
    final change = _reason == 'stock_out' || _reason == 'damaged' || _reason == 'theft' ? -qty : qty;
    await ref.read(databaseProvider).addStockAdjustment({
      'id': Uuid().v4(), 'product_id': widget.productId,
      'quantity_change': change, 'reason': _reason,
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      'user_id': userId, 'created_at': DateTime.now().toIso8601String(),
    });
    ref.invalidate(productDetailProvider(widget.productId));
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock adjusted by $change'))); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust Stock')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Reason'),
          value: _reason,
          items: const [
            DropdownMenuItem(value: 'stock_in', child: Text('Stock In (Purchase)')),
            DropdownMenuItem(value: 'stock_out', child: Text('Stock Out (Sale)')),
            DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
            DropdownMenuItem(value: 'theft', child: Text('Theft / Lost')),
            DropdownMenuItem(value: 'return', child: Text('Return from Customer')),
            DropdownMenuItem(value: 'correction', child: Text('Count Correction')),
          ],
          onChanged: (v) { if (v != null) setState(() => _reason = v); },
        ),
        const SizedBox(height: 12),
        TextField(controller: _qtyC, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        TextField(controller: _notesC, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
        const SizedBox(height: 16),
        SizedBox(height: 48, child: ElevatedButton(onPressed: _save, child: const Text('Save Adjustment'))),
      ])),
    );
  }
}
