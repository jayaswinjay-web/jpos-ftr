import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';
import '../../../services/openwa_service.dart' show openwaServiceProvider;

class CustomerScreen extends ConsumerStatefulWidget {
  const CustomerScreen({super.key});
  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _promoMsgC = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  void _search(String q) async {
    if (q.trim().isEmpty) { setState(() { _results = []; _searching = false; }); return; }
    setState(() => _searching = true);
    final db = ref.read(databaseProvider);
    final r = await db.searchCustomers(q.trim());
    if (!mounted) return;
    setState(() { _results = r; _searching = false; });
  }

  @override
  void dispose() {
    _searchController.dispose(); _nameController.dispose(); _phoneController.dispose(); _promoMsgC.dispose();
    super.dispose();
  }

  void _showAddCustomerSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Text('Add Customer', style: Theme.of(ctx).textTheme.titleLarge), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Customer Name *')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number *'), keyboardType: TextInputType.phone),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 48, child: ElevatedButton(onPressed: () async {
            if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Name and phone required'))); return;
            }
            final now = DateTime.now().toIso8601String();
            await ref.read(databaseProvider).insertCustomer({
              'id': Uuid().v4(), 'name': _nameController.text.trim(), 'phone': _phoneController.text.trim(),
              'email': null, 'gstin': null, 'address': null, 'loyalty_points': 0, 'total_spent': 0,
              'is_active': 1, 'created_at': now, 'updated_at': now,
            });
            _nameController.clear(); _phoneController.clear();
            ref.invalidate(allCustomersProvider);
            Navigator.pop(ctx);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer added')));
          }, child: const Text('Add Customer'))),
          const SizedBox(height: AppSpacing.lg),
        ]),
      ),
    );
  }

  void _showPromoDialog() {
    _promoMsgC.clear();
    showDialog(context: context, builder: (d) => AlertDialog(
      title: const Text('Send Promo / Broadcast'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Message will be sent to all customers with phone numbers via WhatsApp.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        TextField(controller: _promoMsgC, decoration: const InputDecoration(labelText: 'Message', hintText: 'Enter your promo message...'), maxLines: 4),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (_promoMsgC.text.trim().isEmpty) return;
          final customers = ref.read(allCustomersProvider).valueOrNull ?? [];
          final phones = customers.where((c) => c['phone'] != null).map((c) => c['phone'] as String).toList();
          if (phones.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No customers with phone numbers'))); return; }
          final openwa = ref.read(openwaServiceProvider);
          int sent = 0;
          for (final phone in phones.take(50)) {
            try { await openwa.sendMessage(phone: phone, message: _promoMsgC.text.trim()); sent++; } catch (_) {}
          }
          Navigator.pop(d);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Promo sent to $sent customers')));
        }, child: const Text('Send to All')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = ref.watch(allCustomersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers'), actions: [
        IconButton(icon: const Icon(Icons.send), onPressed: _showPromoDialog, tooltip: 'Send Promo'),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(AppSpacing.md), child: TextField(
          controller: _searchController,
          decoration: InputDecoration(hintText: 'Search by name or phone', prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _results = []; _searching = false; }); }) : null),
          onChanged: _search,
        )),
        Expanded(child: _searching
          ? (_results.isEmpty ? const Center(child: Text('No results')) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), itemCount: _results.length, itemBuilder: (_, i) => _customerCard(theme, _results[i])))
          : customers.when(data: (list) => list.isEmpty ? const Center(child: Text('No customers yet')) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), itemCount: list.length, itemBuilder: (_, i) => _customerCard(theme, list[i])), loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('Error: $e'))),
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _showAddCustomerSheet, child: const Icon(Icons.person_add)),
    );
  }

  Widget _customerCard(ThemeData theme, Map<String, dynamic> c) {
    final pts = c['loyalty_points'] as int? ?? 0;
    final spent = c['total_spent'] as int? ?? 0;
    return Card(margin: const EdgeInsets.only(bottom: AppSpacing.sm), child: ListTile(
      onTap: () => context.go('/customers/${c['id']}'),
      leading: CircleAvatar(backgroundColor: AppColors.primaryContainer,
        child: Text((c['name'] as String? ?? '?')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
      title: Text(c['name'] as String),
      subtitle: Text(c['phone'] as String? ?? ''),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (pts > 0) Text('$pts pts', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: AppColors.primary)),
        Text(Money(spent).formatCompact(), style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
      ]),
    ));
  }
}
