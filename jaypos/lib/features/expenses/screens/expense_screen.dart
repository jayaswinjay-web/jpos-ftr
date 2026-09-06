import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';
import '../../auth/controllers/auth_controller.dart';

final currentMonthExpensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  return db.getExpenses(month: now.month, year: now.year);
});

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});
  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  final _catC = 'rent';
  final _amtC = TextEditingController();
  final _descC = TextEditingController();

  @override
  void dispose() { _amtC.dispose(); _descC.dispose(); super.dispose(); }

  void _showAddExpenseSheet() {
    String category = _catC;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add Expense', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              value: category,
              items: const [
                DropdownMenuItem(value: 'rent', child: Text('Rent')),
                DropdownMenuItem(value: 'salary', child: Text('Salary')),
                DropdownMenuItem(value: 'utilities', child: Text('Utilities')),
                DropdownMenuItem(value: 'stock', child: Text('Stock Purchase')),
                DropdownMenuItem(value: 'misc', child: Text('Miscellaneous')),
              ],
              onChanged: (v) { if (v != null) setSheetState(() => category = v); },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _amtC, decoration: const InputDecoration(labelText: 'Amount (₹)'), keyboardType: TextInputType.number),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _descC, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 48, child: ElevatedButton(onPressed: () async {
              final amt = ((double.tryParse(_amtC.text) ?? 0) * 100).round();
              if (amt <= 0) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter valid amount'))); return; }
              final uid = ref.read(authControllerProvider).userId;
              await ref.read(databaseProvider).addExpense({
                'id': Uuid().v4(), 'category': category, 'amount': amt,
                'description': _descC.text.trim().isEmpty ? null : _descC.text.trim(),
                'notes': null, 'photo_path': null, 'user_id': uid,
                'created_at': DateTime.now().toIso8601String(),
              });
              _amtC.clear(); _descC.clear();
              ref.invalidate(currentMonthExpensesProvider);
              Navigator.pop(ctx);
            }, child: const Text('Add Expense'))),
            const SizedBox(height: AppSpacing.lg),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses = ref.watch(currentMonthExpensesProvider);
    final total = expenses.valueOrNull?.fold<int>(0, (s, e) => s + (e['amount'] as int)) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses'), actions: [
        TextButton(onPressed: () {}, child: const Text('This Month')),
      ]),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(AppSpacing.md), color: AppColors.dangerContainer.withOpacity(0.3),
          child: Row(children: [
            const Icon(Icons.money_off, color: AppColors.danger),
            const SizedBox(width: AppSpacing.md),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Expenses (This Month)', style: theme.textTheme.bodyMedium),
              Text(Money(total).format(), style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.danger)),
            ]),
          ]),
        ),
        Expanded(
          child: expenses.when(
            data: (list) => list.isEmpty
              ? const Center(child: Text('No expenses this month'))
              : ListView.builder(padding: const EdgeInsets.all(AppSpacing.md), itemCount: list.length,
                  itemBuilder: (_, i) => _expenseCard(theme, list[i])),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _showAddExpenseSheet, child: const Icon(Icons.add)),
    );
  }

  Widget _expenseCard(ThemeData theme, Map<String, dynamic> e) {
    final cat = e['category'] as String? ?? 'misc';
    final catNames = {'rent': 'Rent', 'salary': 'Salary', 'utilities': 'Utilities', 'stock': 'Stock Purchase', 'misc': 'Miscellaneous'};
    return Card(margin: const EdgeInsets.only(bottom: AppSpacing.sm), child: ListTile(
      leading: Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.dangerContainer, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: const Icon(Icons.receipt, color: AppColors.danger, size: 20)),
      title: Text(catNames[cat] ?? cat),
      subtitle: Text((e['created_at'] as String?)?.substring(0, 10) ?? ''),
      trailing: Text(Money(e['amount'] as int).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
    ));
  }
}
