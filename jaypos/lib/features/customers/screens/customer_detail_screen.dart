import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';

final customerDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  return ref.read(databaseProvider).getCustomer(id);
});

final customerTxProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  return ref.read(databaseProvider).getTransactionsByCustomer(id);
});

final customerLedgerProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  return ref.read(databaseProvider).getLoyaltyLedger(id);
});

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});
  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(customerDetailProvider(widget.customerId));
    final txs = ref.watch(customerTxProvider(widget.customerId));
    final ledger = ref.watch(customerLedgerProvider(widget.customerId));

    return c.when(
      data: (cust) => cust == null
        ? Scaffold(appBar: AppBar(title: const Text('Customer')), body: const Center(child: Text('Not found')))
        : Scaffold(
            appBar: AppBar(title: Text(cust['name'] as String)),
            body: Column(children: [
              Container(padding: const EdgeInsets.all(16), child: Row(children: [
                CircleAvatar(radius: 28, child: Text((cust['name'] as String)[0].toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 24))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cust['phone'] as String? ?? '', style: const TextStyle(fontSize: 14)),
                  Text('${cust['visit_count'] ?? 0} visits', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Money(cust['total_spent'] as int? ?? 0).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
                  Text('${cust['loyalty_points'] ?? 0} pts', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                ]),
              ])),
              TabBar(controller: _tc, tabs: const [Tab(text: 'Transactions'), Tab(text: 'Loyalty'), Tab(text: 'Info')]),
              Expanded(child: TabBarView(controller: _tc, children: [
                txs.when(data: (list) => list.isEmpty ? const Center(child: Text('No transactions')) : ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
                  final tx = list[i];
                  return ListTile(title: Text(tx['invoice_no'] as String), subtitle: Text((tx['created_at'] as String?)?.substring(0, 10) ?? ''),
                    trailing: Text(Money(tx['total'] as int).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)));
                }), loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('$e'))),
                ledger.when(data: (list) => list.isEmpty ? const Center(child: Text('No loyalty activity')) : ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
                  final e = list[i];
                  final pts = e['points_change'] as int;
                  return ListTile(
                    leading: Icon(pts > 0 ? Icons.add_circle : Icons.remove_circle, color: pts > 0 ? AppColors.success : AppColors.danger),
                    title: Text(e['reason'] as String), subtitle: Text((e['created_at'] as String?)?.substring(0, 10) ?? ''),
                    trailing: Text(pts > 0 ? '+$pts' : '$pts', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: pts > 0 ? AppColors.success : AppColors.danger)));
                }), loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('$e'))),
                ListView(padding: const EdgeInsets.all(16), children: [
                  _infoRow('Email', cust['email'] as String? ?? 'N/A'),
                  _infoRow('Address', cust['address'] as String? ?? 'N/A'),
                  _infoRow('Notes', cust['notes'] as String? ?? 'N/A'),
                  _infoRow('Last Visit', (cust['last_visit'] as String?)?.substring(0, 10) ?? 'Never'),
                ]),
              ])),
            ]),
          ),
      loading: () => Scaffold(appBar: AppBar(title: const Text('Customer')), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Customer')), body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _infoRow(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 80, child: Text(l, style: const TextStyle(color: AppColors.onSurfaceVariant))),
    Expanded(child: Text(v)),
  ]));
}
