import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/di/providers.dart';

class SupplierScreen extends ConsumerStatefulWidget {
  const SupplierScreen({super.key});
  @override
  ConsumerState<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends ConsumerState<SupplierScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstinController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  void _showAddSupplierSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Add Supplier', style: Theme.of(ctx).textTheme.titleLarge),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Supplier Name *')),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _gstinController, decoration: const InputDecoration(labelText: 'GSTIN')),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 48, child: ElevatedButton(onPressed: () async {
              if (_nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Supplier name required')));
                return;
              }
              final now = DateTime.now().toIso8601String();
              await ref.read(databaseProvider).insertSupplier({
                'id': Uuid().v4(),
                'name': _nameController.text.trim(),
                'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                'email': null, 'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim().toUpperCase(),
                'address': null, 'is_active': 1, 'created_at': now, 'updated_at': now,
              });
              _nameController.clear(); _phoneController.clear(); _gstinController.clear();
              ref.invalidate(allSuppliersProvider);
              Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier added')));
            }, child: const Text('Add Supplier'))),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliers = ref.watch(allSuppliersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      body: suppliers.when(
        data: (list) => list.isEmpty
          ? const Center(child: Text('No suppliers yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              itemBuilder: (_, i) => _supplierCard(theme, list[i]),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSupplierSheet,
        child: const Icon(Icons.add_business),
      ),
    );
  }

  Widget _supplierCard(ThemeData theme, Map<String, dynamic> s) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.secondaryContainer,
        child: const Icon(Icons.business, color: AppColors.secondary),
      ),
      title: Text(s['name'] as String),
      subtitle: Text(s['phone'] as String? ?? ''),
      trailing: s['gstin'] != null
          ? Text('GST: ${s['gstin']}', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11))
          : null,
    ),
  );
}
