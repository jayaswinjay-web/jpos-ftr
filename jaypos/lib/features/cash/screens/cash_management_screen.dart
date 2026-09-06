import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';
import '../../auth/controllers/auth_controller.dart';

final todayCashFlowsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getCashFlows(DateTime.now());
});

final cashBalanceProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getCashBalance();
});

class CashManagementScreen extends ConsumerStatefulWidget {
  const CashManagementScreen({super.key});
  @override
  ConsumerState<CashManagementScreen> createState() => _CashManagementScreenState();
}

class _CashManagementScreenState extends ConsumerState<CashManagementScreen> {
  final _amountC = TextEditingController();
  final _reasonC = TextEditingController();
  int? _openingBalance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOpening());
  }

  Future<void> _loadOpening() async {
    final db = ref.read(databaseProvider);
    final bal = await db.getCashBalance();
    if (mounted) setState(() => _openingBalance = bal);
  }

  @override
  void dispose() { _amountC.dispose(); _reasonC.dispose(); super.dispose(); }

  void _showEntryDialog(String type) {
    _amountC.clear(); _reasonC.clear();
    showDialog(context: context, builder: (d) => AlertDialog(
      title: Text(type == 'in' ? 'Cash In' : 'Cash Out'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _amountC, decoration: const InputDecoration(labelText: 'Amount (₹)'), keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        TextField(controller: _reasonC, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final amt = ((double.tryParse(_amountC.text) ?? 0) * 100).round();
          if (amt <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid amount'))); return; }
          final uid = ref.read(authControllerProvider).userId;
          await ref.read(databaseProvider).addCashFlow({
            'id': Uuid().v4(), 'type': type,
            'amount': type == 'out' ? -amt : amt,
            'reason': _reasonC.text.trim().isEmpty ? (type == 'in' ? 'Cash deposit' : 'Cash withdrawal') : _reasonC.text.trim(),
            'user_id': uid, 'created_at': DateTime.now().toIso8601String(),
          });
          ref.invalidate(todayCashFlowsProvider);
          ref.invalidate(cashBalanceProvider);
          Navigator.pop(d);
        }, child: const Text('Save')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flows = ref.watch(todayCashFlowsProvider);
    final balance = ref.watch(cashBalanceProvider);

    final cashIn = flows.valueOrNull?.where((f) => f['type'] == 'in' || f['type'] == 'open').fold<int>(0, (s, f) => s + (f['amount'] as int)) ?? 0;
    final cashOut = flows.valueOrNull?.where((f) => f['type'] == 'out').fold<int>(0, (s, f) => s + (f['amount'] as int)) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Management'), actions: [
        IconButton(icon: const Icon(Icons.print), onPressed: () {}),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.warningContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.money, color: AppColors.warning)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Opening Balance', style: theme.textTheme.bodyMedium),
            Text(Money(balance.valueOrNull ?? _openingBalance ?? 0).format(),
                style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700)),
          ])),
          OutlinedButton(onPressed: () {}, child: const Text('Set')),
        ]))),
        const SizedBox(height: AppSpacing.md),
        Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(children: [
          Row(children: [
            Icon(Icons.trending_up, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            Text('Cash In: ', style: theme.textTheme.bodyMedium),
            Text(Money(cashIn).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: AppColors.success)),
            const Spacer(),
            Icon(Icons.trending_down, color: AppColors.danger),
            const SizedBox(width: AppSpacing.sm),
            Text('Cash Out: ', style: theme.textTheme.bodyMedium),
            Text(Money(cashOut.abs()).format(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: AppColors.danger)),
          ]),
          const Divider(height: AppSpacing.lg),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Expected Cash', style: theme.textTheme.bodyMedium),
            Text(Money((balance.valueOrNull ?? 0) + cashIn + cashOut).format(),
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 18)),
          ]),
        ]))),
        const SizedBox(height: AppSpacing.md),
        Text("Today's Entries", style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        flows.when(
          data: (list) => list.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No entries today')))
            : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: list.length,
                itemBuilder: (_, i) => _entryTile(theme, list[i])),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _showEntryDialog('in'), icon: const Icon(Icons.add), label: const Text('Cash In'))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: OutlinedButton.icon(onPressed: () => _showEntryDialog('out'), icon: const Icon(Icons.remove), label: const Text('Cash Out'))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.lock), label: const Text('Close Day'))),
        ]),
      ])),
    );
  }

  Widget _entryTile(ThemeData theme, Map<String, dynamic> f) {
    final isIn = f['type'] == 'in' || f['type'] == 'open';
    return ListTile(
      leading: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? AppColors.success : AppColors.danger),
      title: Text(isIn ? 'Cash In' : 'Cash Out'),
      subtitle: Text(f['reason'] as String? ?? ''),
      trailing: Text(Money((f['amount'] as int).abs()).format(),
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: isIn ? AppColors.success : AppColors.danger)),
    );
  }
}
