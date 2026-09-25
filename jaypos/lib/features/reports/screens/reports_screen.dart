import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';

final monthSalesProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMonthSales(DateTime.now().month, DateTime.now().year);
});

final paymentSummaryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getPaymentSummary();
});

final taxSummaryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getTaxSummary();
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todaySalesProvider);
    final month = ref.watch(monthSalesProvider);
    final payments = ref.watch(paymentSummaryProvider);
    final top = ref.watch(topProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: const [
          Tab(text: 'Sales'), Tab(text: 'Payment'), Tab(text: 'Products'), Tab(text: 'Tax'),
        ]),
        actions: [IconButton(icon: const Icon(Icons.download), onPressed: () async {
          final db = ref.read(databaseProvider);
          final txns = await db.getTransactions(limit: 500);
          if (!mounted) return;
          final csv = StringBuffer('Invoice No,Date,Type,Customer,Subtotal,Discount,Tax,Total,Amount Paid,Change\n');
          for (final t in txns) {
            csv.writeln('${t['invoice_no']},${(t['created_at'] as String).substring(0,10)},${t['transaction_type']},${t['customer_id'] ?? ''},${t['subtotal']},${t['discount_amount']},${t['tax_amount']},${t['total']},${t['amount_paid']},${t['change_amount']}');
          }
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/sales_export.csv');
          await file.writeAsString(csv.toString());
          await Share.shareXFiles([XFile(file.path)], text: 'Sales Report CSV');
        })],
      ),
      body: SafeArea(child: TabBarView(controller: _tabController, children: [
        _buildSalesReport(theme, today, month),
        _buildPaymentReport(theme, payments),
        _buildProductReport(theme, top),
        _buildTaxReport(theme),
      ])),
    );
  }

  Widget _buildSalesReport(ThemeData theme, AsyncValue<int> today, AsyncValue<int> month) {
    final t = today.valueOrNull ?? 0;
    final m = month.valueOrNull ?? 0;
    final daysPassed = DateTime.now().day;
    final avg = daysPassed > 0 ? m ~/ daysPassed : 0;
    final weekSales = ref.watch(weekSalesProvider).valueOrNull ?? [];
    final map = {for (final r in weekSales) r['dow'] as int: r['total'] as int};
    final List<double> weekValues = List.generate(7, (i) {
      final sqlDow = i == 0 ? 0 : i;
      return (map[sqlDow] ?? 0).toDouble();
    });
    final weekTotal = weekValues.fold(0.0, (a, b) => a + b).toInt();
    return SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sales Summary', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(child: _StatCard(title: 'Today', value: Money(t).format(), color: AppColors.primary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _StatCard(title: 'This Week', value: Money(weekTotal).formatCompact(), color: AppColors.success)),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(child: _StatCard(title: 'This Month', value: Money(m).formatCompact(), color: AppColors.info)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _StatCard(title: 'Avg/Day', value: Money(avg).format(), color: AppColors.warning)),
      ]),
      const SizedBox(height: AppSpacing.md),
      Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Last 7 Days', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        SizedBox(height: 200, child: LineChart(LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
              getTitlesWidget: (v, _) => Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][v.toInt()], style: const TextStyle(fontSize: 10)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [LineChartBarData(
            spots: List.generate(7, (i) => FlSpot(i.toDouble(), weekValues[i])),
            isCurved: true, color: AppColors.primary, barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.1)),
          )],
        ))),
      ]))),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () async {
          final db = ref.read(databaseProvider);
          final txns = await db.getTransactions(limit: 500);
          if (!mounted) return;
          final csv = StringBuffer('Invoice No,Date,Subtotal,Tax,Total\n');
          for (final t in txns) {
            csv.writeln('${t['invoice_no']},${(t['created_at'] as String).substring(0,10)},${t['subtotal']},${t['tax_amount']},${t['total']}');
          }
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/sales_report.csv');
          await file.writeAsString(csv.toString());
          await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');
        }, icon: const Icon(Icons.table_chart, size: 18), label: const Text('CSV'))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.grid_on, size: 18), label: const Text('Excel'))),
      ]),
    ]));
  }

  Widget _buildPaymentReport(ThemeData theme, AsyncValue<List<Map<String, dynamic>>> payments) {
    final p = payments.valueOrNull ?? [];
    final total = p.fold<int>(0, (s, r) => s + (r['total'] as int));
    return Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Payment Methods', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      SizedBox(height: 200, child: PieChart(PieChartData(
        sections: p.isEmpty
          ? [PieChartSectionData(value: 100, title: 'No Data', color: Colors.grey, radius: 50)]
          : p.map((r) => PieChartSectionData(
              value: total > 0 ? (r['total'] as int) / total * 100 : 0,
              title: r['payment_method'] as String? ?? '',
              color: _paymentColor(r['payment_method'] as String? ?? ''),
              radius: 50,
            )).toList(),
        centerSpaceRadius: 40,
      ))),
      const SizedBox(height: AppSpacing.md),
      ...p.map((r) => _paymentRow(
        r['payment_method'] as String? ?? '',
        total > 0 ? ((r['total'] as int) / total * 100) : 0,
        Money(r['total'] as int),
        _paymentColor(r['payment_method'] as String? ?? ''),
      )),
    ]));
  }

  Widget _buildProductReport(ThemeData theme, AsyncValue<List<Map<String, dynamic>>> top) {
    return top.when(
      data: (list) => list.isEmpty
        ? const Center(child: Text('No sales data'))
        : ListView.builder(padding: const EdgeInsets.all(AppSpacing.md), itemCount: list.length,
            itemBuilder: (_, i) => Card(margin: const EdgeInsets.only(bottom: AppSpacing.sm), child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700))),
              title: Text(list[i]['product_name'] as String? ?? 'Unknown'),
              subtitle: Text('${list[i]['qty']} units sold'),
              trailing: Text(Money((list[i]['total'] as int?) ?? 0).formatCompact(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
            ))),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildTaxReport(ThemeData theme) {
    final taxData = ref.watch(taxSummaryProvider).valueOrNull ?? [];
    final totalTax = taxData.fold<int>(0, (s, r) => s + (r['tax'] as int));
    return SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tax Summary', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(children: [
        if (taxData.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No tax data yet'))
        else
          ...taxData.map((r) => _taxRow('GST ${r['tax_rate']}%', Money(r['tax'] as int))),
        if (taxData.isNotEmpty) const Divider(),
        if (taxData.isNotEmpty) _taxRow('Total Tax', Money(totalTax), bold: true),
      ]))),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  final data = await db.getTaxSummary();
                  if (!mounted) return;
                  final csv = StringBuffer('Tax Rate,Tax Amount\n');
                  for (final r in data) {
                    csv.writeln('${r['tax_rate']}%,${r['tax']}');
                  }
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/gstr1.csv');
                  await file.writeAsString(csv.toString());
                  await Share.shareXFiles([XFile(file.path)], text: 'GSTR-1 Report');
                },
                icon: const Icon(Icons.description, size: 18),
                label: const Text('GSTR-1'),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  final data = await db.getTaxSummary();
                  if (!mounted) return;
                  final csv = StringBuffer('Tax Rate,Tax Amount\n');
                  for (final r in data) {
                    csv.writeln('${r['tax_rate']}%,${r['tax']}');
                  }
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/gstr3b.csv');
                  await file.writeAsString(csv.toString());
                  await Share.shareXFiles([XFile(file.path)], text: 'GSTR-3B Report');
                },
                icon: const Icon(Icons.description, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('GSTR-3B'),
                ),
              ),
            ),
          ),
        ],
      ),
    ]));
  }

  Color _paymentColor(String m) {
    switch (m.toLowerCase()) {
      case 'cash': return AppColors.success;
      case 'upi': return AppColors.primary;
      case 'card': return AppColors.warning;
      case 'split': return AppColors.info;
      default: return Colors.grey;
    }
  }

  Widget _paymentRow(String label, double percent, Money amount, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: AppSpacing.sm),
      SizedBox(width: 60, child: Text(label)),
      Expanded(child: LinearProgressIndicator(value: percent / 100, backgroundColor: color.withOpacity(0.2), color: color)),
      const SizedBox(width: AppSpacing.sm),
      Text('${percent.toInt()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(width: AppSpacing.sm),
      Text(amount.formatCompact(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
    ]));
  }

  Widget _taxRow(String label, Money amount, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text(amount.format(), style: GoogleFonts.spaceGrotesk(fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
    ]));
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
    ])));
  }
}
