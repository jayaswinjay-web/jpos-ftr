import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';
import '../../../services/scanner_service.dart';
import '../../auth/controllers/auth_controller.dart';

class ReturnRefundScreen extends ConsumerStatefulWidget {
  const ReturnRefundScreen({super.key});
  @override
  ConsumerState<ReturnRefundScreen> createState() => _ReturnRefundScreenState();
}

class _ReturnRefundScreenState extends ConsumerState<ReturnRefundScreen> {
  final _invC = TextEditingController();
  Map<String, dynamic>? _tx;
  List<Map<String, dynamic>> _items = [];
  final _reasonC = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scannerServiceProvider).onVolumeDown = () => _openScanner();
    });
  }

  void _openScanner() {
    showDialog(context: context, builder: (d) => AlertDialog(
      title: const Text('Scan Invoice Barcode'),
      content: SizedBox(width: 300, height: 350, child: MobileScanner(
        onDetect: (capture) {
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null) { _invC.text = code; Navigator.pop(d); _lookup(); }
        },
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel'))],
    ));
  }

  void _lookup() async {
    if (_invC.text.trim().isEmpty) return;
    setState(() { _loading = true; _tx = null; _items = []; });
    final db = ref.read(databaseProvider);
    final tx = await db.getTransactionByInvoice(_invC.text.trim());
    if (tx != null) {
      _items = await db.getTransactionItems(tx['id']);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice not found'), backgroundColor: AppColors.danger));
    }
    if (mounted) setState(() { _tx = tx; _loading = false; });
  }

  void _refund() async {
    if (_tx == null) return;
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication required'))); return; }
    final amount = _tx!['total'] as int;
    await ref.read(databaseProvider).createRefund(_tx!['id'], amount, _reasonC.text.trim().isEmpty ? 'Customer return' : _reasonC.text.trim(), userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refund of ${Money(amount).format()} processed'), backgroundColor: AppColors.success));
      setState(() { _tx = null; _items = []; _invC.clear(); _reasonC.clear(); });
    }
  }

  @override
  void dispose() { ref.read(scannerServiceProvider).onVolumeDown = null; _invC.dispose(); _reasonC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Return / Refund')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _invC, decoration: InputDecoration(
          labelText: 'Invoice Number', prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_invC.text.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () { _invC.clear(); setState(() { _tx = null; _items = []; }); }),
            IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _openScanner),
          ]),
        ), onSubmitted: (_) => _lookup()),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _lookup, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Find Invoice'))),
        if (_tx != null) ...[
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invoice: ${_tx!['invoice_no']}', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            Text('Date: ${(_tx!['created_at'] as String?)?.substring(0, 10) ?? ''}', style: const TextStyle(fontSize: 12)),
            const Divider(),
            ..._items.map((it) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              Expanded(child: Text('${it['product_name']} x${it['quantity']}')),
              Text(Money(it['line_total'] as int).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
            ]))),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total Refund', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(Money(_tx!['total'] as int).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: AppColors.danger)),
            ]),
          ]))),
          const SizedBox(height: 12),
          TextField(controller: _reasonC, decoration: const InputDecoration(labelText: 'Reason for Return'), maxLines: 2),
          const SizedBox(height: 16),
          SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _refund, icon: const Icon(Icons.replay), label: Text('Process Refund of ${Money(_tx!['total'] as int).format()}'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger))),
        ],
      ])),
    );
  }
}
