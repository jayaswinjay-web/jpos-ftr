import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 600;
    final sales = ref.watch(todaySalesProvider);
    final txCount = ref.watch(todayTxCountProvider);
    final lowStock = ref.watch(lowStockProductsProvider);
    final topProducts = ref.watch(topProductsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.valueOrNull?['store_name'] ?? 'Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(todaySalesProvider)),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.go('/settings')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 100, child: ListView(scrollDirection: Axis.horizontal, children: [
              _statCard("Today's Sales", sales.when(data: (d) => Money(d).format(), loading: () => '...', error: (_,__) => '₹0'), Icons.trending_up, AppColors.success, AppColors.successContainer),
              const SizedBox(width: 8),
              _statCard('Transactions', txCount.when(data: (d) => '$d', loading: () => '...', error: (_,__) => '0'), Icons.receipt_long, AppColors.primary, AppColors.primaryContainer),
              const SizedBox(width: 8),
              _statCard('Avg Ticket', sales.when(data: (d) => txCount.when(data: (c) => c > 0 ? Money(d ~/ c).format() : '₹0', loading: () => '...', error: (_,__) => '₹0'), loading: () => '...', error: (_,__) => '₹0'), Icons.analytics, AppColors.info, AppColors.infoContainer),
              const SizedBox(width: 8),
              _statCard('Products', '${ref.watch(allProductsProvider).valueOrNull?.length ?? 0}', Icons.inventory_2, AppColors.warning, AppColors.warningContainer),
            ]),
          ),
          const SizedBox(height: 12),
          isWide
            ? Row(children: [Expanded(child: _actionsGrid(t, context)), const SizedBox(width: 12), Expanded(child: _weekChart(t, ref))])
            : Column(children: [_actionsGrid(t, context), const SizedBox(height: 12), _weekChart(t, ref)]),
          const SizedBox(height: 12),
          isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _lowStockSection(t, lowStock)),
                const SizedBox(width: 12),
                Expanded(child: _topProductsSection(t, topProducts)),
              ])
            : Column(children: [
                _lowStockSection(t, lowStock),
                const SizedBox(height: 12),
                _topProductsSection(t, topProducts),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, Color bg) => SizedBox(
    width: 160, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)), child: Icon(icon, size: 16, color: color)),
        const Spacer(),
      ]),
      const Spacer(),
      Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700)),
      Text(title, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
    ]))),
  );

  Widget _actionsGrid(ThemeData t, BuildContext ctx) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Actions', style: t.textTheme.titleMedium),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _actionTile(ctx, Icons.add_circle_outline, 'New Bill', AppColors.primary, '/billing'),
        _actionTile(ctx, Icons.flash_on, 'Quick Bill', AppColors.warning, '/quick-bill'),
        _actionTile(ctx, Icons.inventory_2_outlined, 'Products', AppColors.success, '/inventory'),
        _actionTile(ctx, Icons.analytics_outlined, 'Reports', AppColors.info, '/reports'),
      ]),
    ]),
  ));

  Widget _actionTile(BuildContext ctx, IconData icon, String label, Color color, String route) => SizedBox(
    width: (MediaQuery.of(ctx).size.width - 100) / 4 < 80 ? 72 : (MediaQuery.of(ctx).size.width - 100) / 4,
    child: InkWell(onTap: () => ctx.go(route), borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ]),
      ),
    ),
  );

  Widget _weekChart(ThemeData t, WidgetRef ref) {
    final weekSales = ref.watch(weekSalesProvider);
    final data = weekSales.valueOrNull ?? [];
    final map = {for (final r in data) r['dow'] as int: r['total'] as int};
    final List<double> values = List.generate(7, (i) {
      final sqlDow = i == 0 ? 0 : i; // SQLite %w: Sun=0, Mon=1, ..., Sat=6
      return (map[sqlDow] ?? 0).toDouble();
    });
    final maxY = values.fold(0.0, (a, b) => a > b ? a : b);
    final ceiling = maxY <= 0 ? 10000.0 : ((maxY / 1000).ceil() * 1000).toDouble();
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This Week', style: t.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround, maxY: ceiling,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
              getTitlesWidget: (v, _) => Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][v.toInt()%7], style: const TextStyle(fontSize: 10))))),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: AppColors.primary, width: 12, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)))]))))),
      ]),
    ));
  }

  Widget _lowStockSection(ThemeData t, AsyncValue<List<Map<String, dynamic>>> low) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Low Stock Alerts', style: t.textTheme.titleMedium),
        const Spacer(),
        Text('${low.valueOrNull?.length ?? 0} items', style: TextStyle(color: (low.valueOrNull?.length ?? 0) > 0 ? AppColors.danger : AppColors.success, fontSize: 12)),
      ]),
      const SizedBox(height: 12),
      if (low.valueOrNull == null || low.valueOrNull!.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('All stocked up!', style: TextStyle(color: AppColors.success))))
      else
        ...low.valueOrNull!.map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text(p['name'] as String, style: const TextStyle(fontSize: 13))),
            Text('${p['stock']} / ${p['low_stock_threshold']}', style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
          ]),
        )),
    ]),
  ));

  Widget _topProductsSection(ThemeData t, AsyncValue<List<Map<String, dynamic>>> top) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Top Products', style: t.textTheme.titleMedium),
      const SizedBox(height: 12),
      if (top.valueOrNull == null || top.valueOrNull!.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No sales data yet')))
      else
        ...top.valueOrNull!.map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(p['product_name'] as String? ?? 'Unknown', style: const TextStyle(fontSize: 13))),
            Text('${p['qty']} sold', style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 8),
            Text(Money((p['total'] as int?) ?? 0).format(), style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        )),
    ]),
  ));
}
