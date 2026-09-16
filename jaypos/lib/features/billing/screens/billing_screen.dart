import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';
import '../../../services/scanner_service.dart';
import '../../../data/local/database.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/billing_controller.dart';
import '../widgets/continuous_scanner.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});
  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final _searchCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final _discCtl = TextEditingController();
  final _couponCtl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _attachedCustomer;
  int _loyaltyRedeem = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scannerServiceProvider).onVolumeDown = () => _scanBarcode(context);
    });
  }

  @override void dispose() { ref.read(scannerServiceProvider).onVolumeDown = null; _searchCtl.dispose(); _phoneCtl.dispose(); _notesCtl.dispose(); _discCtl.dispose(); _couponCtl.dispose(); super.dispose(); }

  void _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    final db = ref.read(databaseProvider);
    final results = await db.searchProducts(q.trim());
    if (!mounted) return;
    setState(() { _searchResults = results; });
  }

  void _attachCustomer(String phone) async {
    if (phone.trim().isEmpty) {
      setState(() { _attachedCustomer = null; _loyaltyRedeem = 0; });
      ref.read(billingControllerProvider.notifier).clearLoyaltyRedeem();
      return;
    }
    final db = ref.read(databaseProvider);
    final cust = await db.getCustomerByPhone(phone.trim());
    if (!mounted) return;
    if (cust != null) {
      setState(() => _attachedCustomer = cust);
      ref.read(billingControllerProvider.notifier).setCustomer(cust);
    }
  }

  void _applyCoupon() async {
    final code = _couponCtl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final bill = ref.read(billingControllerProvider);
    final db = ref.read(databaseProvider);
    final valid = await db.redeemCoupon(code, bill.total);
    if (!mounted) return;
    if (!valid) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid or expired coupon'))); return; }
    await ref.read(billingControllerProvider.notifier).setCoupon(code);
    if (!mounted) return;
    final updated = ref.read(billingControllerProvider);
    if (updated.couponDiscount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coupon applied! Discount: ${Money(updated.couponDiscount).format()}'), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bill = ref.watch(billingControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('New Bill'), actions: [
        IconButton(icon: const Icon(Icons.flash_on), tooltip: 'Fast Scan', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContinuousScanner()))),
        IconButton(icon: const Icon(Icons.pause_circle_outline), tooltip: 'Hold Bill', onPressed: () async {
          if (bill.items.isEmpty) return;
          await ref.read(billingControllerProvider.notifier).holdBill(auth.userId ?? '');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill held')));
        },),
        IconButton(icon: const Icon(Icons.replay), tooltip: 'Recall Held', onPressed: () => _showHeldBills(context)),
        IconButton(icon: const Icon(Icons.percent), tooltip: 'Discount', onPressed: () => _showDiscount(context)),
        IconButton(icon: const Icon(Icons.undo), tooltip: 'Return', onPressed: () => context.go('/return-refund')),
      ],),
      body: Column(children: [
        Expanded(child: isWide
          ? Row(children: [Expanded(flex: 3, child: _buildLeft(t)), const VerticalDivider(width: 1), Expanded(flex: 2, child: _buildRight(t, bill, auth))])
          : Column(children: [Expanded(child: _buildLeft(t)), const Divider(height: 1), Expanded(child: _buildRight(t, bill, auth))]),
        ),
        _buildBottomBar(t, bill, auth),
      ],),
    );
  }

  Widget _buildLeft(ThemeData t) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: TextField(
      controller: _searchCtl,
      decoration: InputDecoration(
        hintText: 'Search by name / SKU / barcode',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _scanBarcode(context), tooltip: 'Scan'),
          if (_searchCtl.text.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtl.clear(); _search(''); }),
        ],),
      ), onChanged: _search,
    ),),
    Expanded(child: _searchResults.isEmpty
      ? (_searchCtl.text.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search, size: 48, color: t.colorScheme.outline),
              const SizedBox(height: 8), Text('Search products above', style: t.textTheme.bodyMedium),
            ],),)
          : Center(child: Text('No products found', style: t.textTheme.bodyMedium)))
      : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _searchResults.length, itemBuilder: (_, i) {
          final p = _searchResults[i];
          final stock = p['stock'] as int? ?? 0;
          return Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(dense: true,
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.inventory_2, size: 20),),
            title: Text(p['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('SKU: ${p['sku']}  \u2022 Stock: $stock', style: const TextStyle(fontSize: 11)),
            trailing: Text(Money(p['sale_price'] as int).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
            onTap: stock > 0 ? () => ref.read(billingControllerProvider.notifier).addItem(p) : null,
          ),);
        },),
    ),
  ],);

  Widget _buildRight(ThemeData t, BillingState bill, AuthState auth) => Column(children: [
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: TextField(
      controller: _phoneCtl,
      decoration: InputDecoration(
        hintText: 'Customer phone',
        prefixIcon: const Icon(Icons.person_outline, size: 18),
        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: _phoneCtl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.check), onPressed: () => _attachCustomer(_phoneCtl.text)) : null,
      ),
      keyboardType: TextInputType.phone,
      onSubmitted: (v) => _attachCustomer(v),
    ),),
    if (_attachedCustomer != null)
      Container(margin: const EdgeInsets.symmetric(horizontal: 12), padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.person, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('${_attachedCustomer!['name']} (${_attachedCustomer!['loyalty_points'] ?? 0} pts)', style: const TextStyle(fontSize: 12))),
          if ((_attachedCustomer!['loyalty_points'] as int? ?? 0) > 0)
            TextButton(onPressed: () => _showLoyaltyRedeem(context), child: const Text('Redeem', style: TextStyle(fontSize: 11))),
        ],),
      ),
    Expanded(child: bill.items.isEmpty
      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.shopping_cart_outlined, size: 48, color: t.colorScheme.outline),
          const SizedBox(height: 8), Text('Cart is empty', style: t.textTheme.bodyMedium),
        ],),)
      : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: bill.items.length, itemBuilder: (_, i) {
          final item = bill.items[i];
          return Card(margin: const EdgeInsets.only(bottom: 4), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(Money(item.unitPrice).format(), style: const TextStyle(fontSize: 11)),
              ],),),
              Row(children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: item.quantity > 1 ? () => ref.read(billingControllerProvider.notifier).updateQty(i, -1) : null),
                Text('${item.quantity}', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
                IconButton(icon: const Icon(Icons.add_circle_outline, size: 18), onPressed: () => ref.read(billingControllerProvider.notifier).updateQty(i, 1)),
              ],),
              SizedBox(width: 80, child: Text(Money(item.unitPrice * item.quantity).format(), textAlign: TextAlign.right, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600))),
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => ref.read(billingControllerProvider.notifier).removeItem(i)),
            ],),
          ),);
        },),
    ),
    Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest.withOpacity(0.5), border: Border(top: BorderSide(color: t.dividerColor))),
      child: Column(children: [
        if (bill.couponCode != null)
          Row(children: [const Icon(Icons.card_giftcard, size: 14, color: AppColors.primary), const SizedBox(width: 4),
            Text('Coupon: ${bill.couponCode} (-${Money(bill.couponDiscount).format()})', style: const TextStyle(fontSize: 11, color: AppColors.primary)),],),
        _tr('Subtotal', Money(bill.subtotal).format(), t),
        _tr('Tax', Money(bill.taxAmount).format(), t),
        if (bill.billDiscount > 0) _tr('Bill Discount', '-${Money(bill.billDiscount).format()}', t, color: AppColors.success),
        if (bill.couponDiscount > 0) _tr('Coupon Discount', '-${Money(bill.couponDiscount).format()}', t, color: AppColors.primary),
        if (_loyaltyRedeem > 0) _tr('Loyalty', '-${Money(_loyaltyRedeem).format()}', t, color: AppColors.primary),
        const Divider(),
        _tr('Total', Money(bill.grandTotal).format(), t, bold: true, large: true),
      ],),
    ),
  ],);

  Widget _buildBottomBar(ThemeData t, BillingState bill, AuthState auth) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: t.colorScheme.surface, border: Border(top: BorderSide(color: t.dividerColor))),
    child: SafeArea(child: Row(children: [
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        ...[('cash', Icons.money), ('upi', Icons.qr_code), ('card', Icons.credit_card)].map((m) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(m.$1.toUpperCase()), selected: bill.paymentMethod == m.$1,
            onSelected: (_) => ref.read(billingControllerProvider.notifier).setPaymentMethod(m.$1),),
        ),),
        ActionChip(label: const Text('Coupon'), onPressed: () => _showCouponDialog(context)),
      ],),),),
      const SizedBox(width: 16),
      SizedBox(height: 48, child: ElevatedButton.icon(
        onPressed: bill.items.isEmpty ? null : () async {
          if (bill.paymentMethod == 'upi') {
            await _handleUpiPayment(context, bill, auth);
          } else if (bill.paymentMethod == 'card') {
            await _handleCardPayment(context, auth);
          } else {
            await _completeCheckout(context, auth);
          }
        },
        icon: const Icon(Icons.receipt_long),
        label: Text('₹${(bill.grandTotal / 100).toStringAsFixed(0)} Pay'),
      ),),
    ],),),
  );

  void _showCouponDialog(BuildContext context) {
    _couponCtl.clear();
    showDialog(context: context, builder: (d) => AlertDialog(
      title: const Text('Apply Coupon'),
      content: TextField(controller: _couponCtl, decoration: InputDecoration(labelText: 'Coupon Code', hintText: 'e.g. SAVE20', prefixStyle: GoogleFonts.spaceGrotesk())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { _applyCoupon(); Navigator.pop(d); }, child: const Text('Apply')),
      ],
    ),);
  }

  void _showLoyaltyRedeem(BuildContext context) {
    final pts = _attachedCustomer!['loyalty_points'] as int;
    final ctl = TextEditingController();
    showDialog(context: context, builder: (d) => AlertDialog(
      title: const Text('Redeem Points'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Available: $pts points (₹$pts)'),
        const SizedBox(height: 12),
        TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Points to redeem'), keyboardType: TextInputType.number),
      ],),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          final r = int.tryParse(ctl.text) ?? 0;
          if (r > 0 && r <= pts) {
            setState(() => _loyaltyRedeem = r * 100);
            ref.read(billingControllerProvider.notifier).setLoyaltyRedeem(r, r * 100);
          }
          Navigator.pop(d);
        }, child: const Text('Apply'),),
      ],
    ),);
  }

  void _showReceipt(BuildContext context, Map<String, dynamic> tx) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Bill Complete'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Invoice: ${tx['invoice_no']}', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 12),
        Text('Subtotal: ${Money(tx['subtotal'] as int).format()}'),
        Text('Tax: ${Money(tx['tax_amount'] as int).format()}'),
        Text('Total: ${Money(tx['total'] as int).format()}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],),
      actions: [
        TextButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('Close')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); context.pushNamed('receipt', pathParameters: {'id': tx['id']}); }, child: const Text('View Receipt')),
      ],
    ),);
  }

  void _showDiscount(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Bill Discount'),
      content: TextField(controller: _discCtl, decoration: const InputDecoration(labelText: 'Discount (%)'), keyboardType: TextInputType.number),
      actions: [
        TextButton(onPressed: () { _discCtl.clear(); ref.read(billingControllerProvider.notifier).setDiscount(0); Navigator.pop(ctx); }, child: const Text('Remove')),
        ElevatedButton(onPressed: () { ref.read(billingControllerProvider.notifier).setDiscount(double.tryParse(_discCtl.text) ?? 0); Navigator.pop(ctx); }, child: const Text('Apply')),
      ],
    ),);
  }

  void _showHeldBills(BuildContext context) async {
    final bills = await ref.read(billingControllerProvider.notifier).getHeldBills();
    if (!mounted) return;
    showModalBottomSheet(context: context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Held Bills', style: Theme.of(context).textTheme.titleLarge)),
      if (bills.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No held bills')),
      ...bills.map((b) => ListTile(
        title: Text(b['label'] as String? ?? 'Bill'),
        subtitle: Text(b['held_at'] as String? ?? ''),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.restore), onPressed: () async {
            await ref.read(billingControllerProvider.notifier).restoreHeldBill(b['bill_data'] as String);
            await ref.read(databaseProvider).deleteHeldBill(b['id'] as String);
            if (mounted) Navigator.pop(ctx);
          },),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
            await ref.read(databaseProvider).deleteHeldBill(b['id'] as String);
            if (mounted) Navigator.pop(ctx);
          },),
        ],),
      ),),
    ],),);
  }

  Future<void> _handleCardPayment(BuildContext context, AuthState auth) async {
    final cardC = TextEditingController();
    final expC = TextEditingController();
    final cvvC = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Card Payment'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: cardC, decoration: const InputDecoration(labelText: 'Card Number', hintText: '4111 1111 1111 1111'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: expC, decoration: const InputDecoration(labelText: 'Expiry', hintText: 'MM/YY'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: cvvC, decoration: const InputDecoration(labelText: 'CVV', hintText: '123'), obscureText: true, keyboardType: TextInputType.number)),
        ],),
        const SizedBox(height: 8),
        const Text('Demo mode: no real charge will be made', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
      ],),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pay')),
      ],
    ),);
    if (confirmed == true && mounted) {
      await _completeCheckout(context, auth);
    }
  }

  Future<void> _handleUpiPayment(BuildContext context, BillingState bill, AuthState auth) async {
    final db = ref.read(databaseProvider);
    final upiId = await db.getSetting('upi_id');
    if (upiId == null || upiId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Set UPI ID in Settings first'), backgroundColor: AppColors.warning,),);
      }
      return;
    }
    final storeName = await db.getSetting('store_name');

    // Create the pending order first: the QR must carry the txnRef that the
    // notification listener will match against. Stock/loyalty/coupons are NOT
    // committed yet — that happens only when the payment is confirmed
    final pending = await ref.read(billingControllerProvider.notifier).createPendingUpiOrder(
      auth.userId ?? '',
      upiId: upiId,
      payeeName: storeName ?? 'Store',
    );
    if (pending == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not create UPI order'), backgroundColor: AppColors.danger,),);
      }
      return;
    }
    if (!context.mounted) return;
    // 'paid' → manual confirmation, 'cancelled' → merchant cancelled,
    // null → dialog dismissed without a choice (treated as cancelled)
    String? outcome;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan & Pay (UPI)'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
          ), child: QrImageView(
            data: pending.upiPayString,
            size: 200, backgroundColor: Colors.white,
          ),),
          const SizedBox(height: 12),
          Text('Pay ${Money(pending.amountPaise).format()} via UPI',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),),
          const SizedBox(height: 4),
          Text(upiId, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Ref: ${pending.txnRef}',
            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),),
        ],),
        actions: [
          TextButton(onPressed: () async {
            final uri = Uri.tryParse(pending.upiPayString);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }, child: const Text('Open UPI App'),),
          TextButton(onPressed: () {
            outcome = 'cancelled';
            Navigator.pop(ctx);
          }, child: const Text('Cancel'),),
          // Manual fallback — unchanged behavior for the merchant, but it now
          // finalizes the same pending order instead of creating a new one.
          ElevatedButton(onPressed: () {
            outcome = 'paid';
            Navigator.pop(ctx);
          }, child: const Text('Payment Received'),),
        ],
      ),
    );

    if (outcome != 'paid') {
      // Cancelled or dismissed — don't leave a stray pending row behind
      await ref.read(billingControllerProvider.notifier)
          .cancelUpiOrder(pending.transactionId);
      return;
    }
    final result = await ref.read(billingControllerProvider.notifier)
        .finalizeUpiOrder(pending.transactionId);
    if (result != null && context.mounted) {
      setState(() { _loyaltyRedeem = 0; _attachedCustomer = null; _phoneCtl.clear(); });
      _showReceipt(context, result);
    }
  }

  Future<void> _completeCheckout(BuildContext context, AuthState auth) async {
    final result = await ref.read(billingControllerProvider.notifier).checkout(auth.userId ?? '');
    if (result != null && context.mounted) {
      setState(() { _loyaltyRedeem = 0; _attachedCustomer = null; _phoneCtl.clear(); });
      _showReceipt(context, result);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checkout failed'), backgroundColor: AppColors.danger));
    }
  }

  void _scanBarcode(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(width: 300, height: 400, child: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull?.rawValue;
          if (barcode != null) {
            Navigator.pop(ctx);
            _searchCtl.text = barcode;
            _search(barcode);
          }
        },
      ),),
    ),);
  }

  Widget _tr(String l, String v, ThemeData t, {bool bold=false, bool large=false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: t.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w600 : null)),
      Text(v, style: GoogleFonts.spaceGrotesk(fontSize: large ? 18 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color)),
    ],),
  );
}
