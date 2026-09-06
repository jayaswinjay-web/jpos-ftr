import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/invoice.dart';
import '../../../core/di/providers.dart';
import '../../auth/controllers/auth_controller.dart';

class QuickBillScreen extends ConsumerStatefulWidget {
  const QuickBillScreen({super.key});
  @override
  ConsumerState<QuickBillScreen> createState() => _QuickBillScreenState();
}

class _QuickBillScreenState extends ConsumerState<QuickBillScreen> {
  String _amountText = '';
  bool _isTaxInclusive = false;
  final _nameCtl = TextEditingController();

  Money get _amountInPaise {
    final paise = (double.tryParse(_amountText) ?? 0) * 100;
    return Money(paise.round());
  }

  Money get _tax {
    if (_amountInPaise.paise == 0) return Money(0);
    if (_isTaxInclusive) return _amountInPaise - _amountInPaise.taxInclusiveBackout(18.0);
    return _amountInPaise.taxAmount(18.0);
  }

  Money get _total {
    if (_isTaxInclusive) return _amountInPaise;
    return _amountInPaise + _tax;
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'C') { _amountText = ''; }
      else if (key == '⌫') { if (_amountText.isNotEmpty) _amountText = _amountText.substring(0, _amountText.length - 1); }
      else if (key == '.') { if (!_amountText.contains('.')) _amountText += _amountText.isEmpty ? '0.' : '.'; }
      else {
        if (_amountText.contains('.') && _amountText.split('.')[1].length >= 2) return;
        _amountText += key;
      }
    });
  }

  String _paymentMethod = 'cash';

  Future<void> _showPaymentPicker() async {
    if (_amountInPaise.paise == 0) return;
    final method = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Select Payment Method', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _methodTile(ctx, 'cash', Icons.money, 'Cash', AppColors.success),
              _methodTile(ctx, 'upi', Icons.qr_code_scanner, 'UPI QR', AppColors.primary),
              _methodTile(ctx, 'card', Icons.credit_card, 'Card', AppColors.warning),
            ]),
          ]),
        ),
      ),
    );
    if (method != null && mounted) {
      setState(() => _paymentMethod = method);
      _checkout();
    }
  }

  Widget _methodTile(BuildContext ctx, String value, IconData icon, String label, Color color) =>
    InkWell(
      onTap: () => Navigator.pop(ctx, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );

  Future<void> _checkout() async {
    if (_amountInPaise.paise == 0) return;
    final invoiceNo = InvoiceGenerator.generate();
    final userId = ref.read(authControllerProvider).userId ?? 'quick';
    final txId = Uuid().v4();
    final now = DateTime.now().toIso8601String();

    final tx = {
      'id': txId, 'invoice_no': invoiceNo, 'transaction_type': 'sale',
      'customer_id': null, 'user_id': userId,
      'subtotal': _amountInPaise.paise,
      'discount_amount': 0, 'discount_percent': 0.0,
      'tax_amount': _tax.paise, 'total': _total.paise,
      'round_off': 0, 'amount_paid': _total.paise, 'change_amount': 0,
      'coupon_code': null, 'notes': _nameCtl.text.isEmpty ? 'Quick bill' : 'Quick bill - ${_nameCtl.text}',
      'created_at': now, 'updated_at': now,
    };

    final items = [{
      'id': Uuid().v4(), 'transaction_id': txId, 'product_id': 'QUICK_BILL',
      'product_name': 'Quick item', 'product_sku': '', 'quantity': 1,
      'unit_price': _amountInPaise.paise, 'tax_rate': 0.0, 'tax_inclusive': 0, 'line_discount': 0,
      'line_total': _amountInPaise.paise,
    }];

    final payments = [{
      'id': Uuid().v4(), 'method': _paymentMethod,
      'amount': _total.paise, 'reference': null, 'created_at': now,
    }];

    await ref.read(databaseProvider).createTransaction(tx, items, payments);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quick Bill $invoiceNo - ${_total.format()}'), backgroundColor: AppColors.success),
      );
    }
    setState(() { _amountText = ''; _nameCtl.clear(); _paymentMethod = 'cash'; });
  }

  @override
  void dispose() { _nameCtl.dispose(); super.dispose(); }

  Widget _keyBtn(String k, ThemeData theme) => Padding(padding: const EdgeInsets.all(4),
    child: SizedBox(height: 56, child: TextButton(
      onPressed: () => _onKeyPress(k),
      style: TextButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest, foregroundColor: theme.colorScheme.onSurface, padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
      child: Text(k, style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w600))),
    ));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Bill')),
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Column(children: [
              TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Customer Name (optional)', isDense: true)),
              const SizedBox(height: AppSpacing.sm),
              Text('Amount', style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(_amountText.isEmpty ? '₹0' : '₹$_amountText',
                style: GoogleFonts.spaceGrotesk(fontSize: 48, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              if (_amountInPaise.paise > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Tax (18%): ${_tax.format()}', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: AppSpacing.md),
                  Text('Total: ${_total.format()}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ]),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Tax Inclusive'),
                Switch(value: _isTaxInclusive, onChanged: (v) => setState(() => _isTaxInclusive = v)),
              ]),
            ]),
          ),
          Expanded(
            child: GridView.count(crossAxisCount: 3, childAspectRatio: 1.5, padding: const EdgeInsets.all(AppSpacing.sm),
              children: <Widget>[
                _keyBtn('7', theme), _keyBtn('8', theme), _keyBtn('9', theme),
                _keyBtn('4', theme), _keyBtn('5', theme), _keyBtn('6', theme),
                _keyBtn('1', theme), _keyBtn('2', theme), _keyBtn('3', theme),
                _keyBtn('.', theme), _keyBtn('0', theme), _keyBtn('00', theme),
                Padding(padding: const EdgeInsets.all(4), child: TextButton(
                  onPressed: () => _onKeyPress('⌫'),
                  style: TextButton.styleFrom(backgroundColor: AppColors.warningContainer, foregroundColor: AppColors.warning, padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  child: const Icon(Icons.backspace_outlined))),
                Padding(padding: const EdgeInsets.all(4), child: TextButton(
                  onPressed: () => _onKeyPress('C'),
                  style: TextButton.styleFrom(backgroundColor: AppColors.dangerContainer, foregroundColor: AppColors.danger, padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  child: const Text('C', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)))),
                Padding(padding: const EdgeInsets.all(4), child: ElevatedButton(
                   onPressed: _amountInPaise.paise == 0 ? null : _showPaymentPicker,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  child: Text('₹${(_total.paise / 100).toStringAsFixed(0)}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700)))),
              ]),
          ),
        ]),
      ),
    );
  }
}
