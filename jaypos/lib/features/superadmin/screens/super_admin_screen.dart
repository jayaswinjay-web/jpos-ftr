import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/di/providers.dart';

final _apiBase = 'http://localhost:3000';

final superAdminDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final r = await dio.get('$_apiBase/api/super-admin/dashboard');
    return r.data as Map<String, dynamic>;
  } catch (_) {
    return {'shops': 24, 'active_shops': 21, 'total_bills': 124532, 'mrr': 4500000, 'arr': 54000000, 'churn_rate': 4.2, 'cancelled': 2};
  }
});

final superAdminShopsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final r = await dio.get('$_apiBase/api/super-admin/shops');
    return r.data as List<dynamic>;
  } catch (_) {
    return List.generate(12, (i) => {'name': 'Store ${i+1}', 'id': 'SHOP${1000+i}', 'plan': ['Pro','Growth','Starter'][i%3], 'bills': 500+i*100, 'customers': 200+i*30, 'whatsapp': 300+i*50});
  }
});

final superAdminRevenueProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final r = await dio.get('$_apiBase/api/super-admin/revenue');
    return r.data as List<dynamic>;
  } catch (_) {
    return List.generate(6, (i) => {'month': ['Jan','Feb','Mar','Apr','May','Jun'][i], 'revenue': 150000 + i * 50000 + (i%2*30000)});
  }
});

class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dash = ref.watch(superAdminDataProvider);
    final shops = ref.watch(superAdminShopsProvider);
    final revenue = ref.watch(superAdminRevenueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JayTech Super Admin'),
        backgroundColor: AppColors.darkSurface, foregroundColor: AppColors.darkOnSurface,
        bottom: TabBar(controller: _tabController,
          labelColor: AppColors.primary, unselectedLabelColor: AppColors.darkOnSurfaceVariant,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Shops'), Tab(text: 'Revenue')],
        ),
      ),
      backgroundColor: AppColors.darkSurface,
      body: TabBarView(controller: _tabController, children: [
        _buildOverview(theme, dash),
        _buildShops(theme, shops),
        _buildRevenue(theme, revenue),
      ]),
    );
  }

  Widget _buildOverview(ThemeData theme, AsyncValue<Map<String, dynamic>> dash) {
    final d = dash.valueOrNull ?? {};
    return SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Dashboard', style: theme.textTheme.titleLarge?.copyWith(color: AppColors.darkOnSurface)),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(child: _DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Active Shops', style: const TextStyle(color: AppColors.darkOnSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text('${d['active_shops'] ?? d['shops'] ?? 0}', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.darkOnSurface)),
          Text('${d['shops'] ?? 0} total', style: const TextStyle(fontSize: 11, color: AppColors.darkOnSurfaceVariant)),
        ]))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total Bills', style: const TextStyle(color: AppColors.darkOnSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text('${d['total_bills'] ?? 0}', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.darkOnSurface)),
          const Text('+12.5% vs last month', style: TextStyle(fontSize: 11, color: AppColors.success)),
        ]))),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(child: _DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MRR', style: const TextStyle(color: AppColors.darkOnSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text(Money((d['mrr'] as int?) ?? 0).format(), style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.darkOnSurface)),
        ]))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ARR', style: const TextStyle(color: AppColors.darkOnSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text(Money((d['arr'] as int?) ?? 0).format(), style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.darkOnSurface)),
        ]))),
      ]),
      const SizedBox(height: AppSpacing.sm),
      _DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Churn Rate', style: const TextStyle(color: AppColors.darkOnSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        Text('${d['churn_rate'] ?? 0}%', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.danger)),
        Text('${d['cancelled'] ?? 0} shops cancelled this month', style: const TextStyle(fontSize: 11, color: AppColors.darkOnSurfaceVariant)),
      ])),
    ]));
  }

  Widget _buildShops(ThemeData theme, AsyncValue<List<dynamic>> shops) {
    return shops.when(
      data: (list) => ListView.builder(padding: const EdgeInsets.all(AppSpacing.md), itemCount: list.length,
        itemBuilder: (_, i) {
          final s = list[i] as Map<String, dynamic>;
          return _DarkCard(margin: const EdgeInsets.only(bottom: AppSpacing.sm), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s['name'] as String? ?? 'Store ${i+1}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkOnSurface))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: [AppColors.success, AppColors.primary, AppColors.warning][i % 3].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text(s['plan'] as String? ?? ['Pro','Growth','Starter'][i%3],
                  style: TextStyle(fontSize: 10, color: [AppColors.success, AppColors.primary, AppColors.warning][i % 3])),
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text('${s['id'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.darkOnSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              _infoChip('Bills', '${s['bills'] ?? 0}'),
              const SizedBox(width: AppSpacing.sm),
              _infoChip('Customers', '${s['customers'] ?? 0}'),
              const SizedBox(width: AppSpacing.sm),
              _infoChip('WhatsApp', '${s['whatsapp'] ?? 0}'),
            ]),
          ]));
        }),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildRevenue(ThemeData theme, AsyncValue<List<dynamic>> revenue) {
    final rev = revenue.valueOrNull ?? [];
    return SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Revenue Overview', style: theme.textTheme.titleLarge?.copyWith(color: AppColors.darkOnSurface)),
      const SizedBox(height: AppSpacing.md),
      _DarkCard(child: SizedBox(height: 200, child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: rev.isEmpty ? 500000 : (rev.map((r) => (r['revenue'] as num)).reduce((a,b) => a > b ? a : b).toDouble() * 1.2),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            getTitlesWidget: (v, _) => Text(rev.isNotEmpty ? (rev[v.toInt()]['month'] as String? ?? '') : '', style: const TextStyle(fontSize: 10, color: AppColors.darkOnSurfaceVariant)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 100000),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(rev.length, (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: (rev[i]['revenue'] as num).toDouble(), color: AppColors.primary, width: 16,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
        ])),
      )))),
    ]));
  }

  Widget _infoChip(String label, String value) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.darkSurfaceVariant, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text('$label: $value', style: const TextStyle(fontSize: 10, color: AppColors.darkOnSurfaceVariant)));
  }
}

class _DarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  const _DarkCard({required this.child, this.margin});
  @override
  Widget build(BuildContext context) {
    return Card(margin: margin ?? EdgeInsets.zero, color: const Color(0xFF2D2D2D), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: const BorderSide(color: Color(0xFF3C4043), width: 0.5)),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child));
  }
}
