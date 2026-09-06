import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/billing/screens/billing_screen.dart';
import '../../features/quickbill/screens/quick_bill_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/product_detail_screen.dart';
import '../../features/inventory/screens/sticker_print_screen.dart';
import '../../features/inventory/screens/stock_adjustment_screen.dart';
import '../../features/customers/screens/customer_screen.dart';
import '../../features/customers/screens/customer_detail_screen.dart';
import '../../features/suppliers/screens/supplier_screen.dart';
import '../../features/cash/screens/cash_management_screen.dart';
import '../../features/expenses/screens/expense_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/team/screens/team_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/coupons/screens/coupons_screen.dart';
import '../../features/receipts/screens/receipt_screen.dart';
import '../../features/receipts/screens/receipt_template_screen.dart';
import '../../features/receipts/screens/return_refund_screen.dart';
import '../../features/superadmin/screens/super_admin_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', name: 'login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/forgot-password', name: 'forgotPassword', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/super-admin', name: 'superAdmin', builder: (_, __) => const SuperAdminScreen()),
      GoRoute(path: '/receipt/:id', name: 'receipt', builder: (_, state) => ReceiptScreen(txId: state.pathParameters['id']!)),
      GoRoute(path: '/receipt-template', name: 'receiptTemplate', builder: (_, __) => const ReceiptTemplateScreen()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => DashboardShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', name: 'dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/billing', name: 'billing', builder: (_, __) => const BillingScreen()),
          GoRoute(path: '/quick-bill', name: 'quickBill', builder: (_, __) => const QuickBillScreen()),
          GoRoute(path: '/inventory', name: 'inventory', builder: (_, __) => const InventoryScreen(), routes: [
            GoRoute(path: 'product/:id', name: 'productDetail', builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!)),
            GoRoute(path: 'sticker-print/:id', name: 'stickerPrint', builder: (_, state) => StickerPrintScreen(productId: state.pathParameters['id']!)),
            GoRoute(path: 'adjust/:id', name: 'stockAdjust', builder: (_, state) => StockAdjustmentScreen(productId: state.pathParameters['id']!)),
          ]),
          GoRoute(path: '/customers', name: 'customers', builder: (_, __) => const CustomerScreen(), routes: [
            GoRoute(path: ':id', name: 'customerDetail', builder: (_, state) => CustomerDetailScreen(customerId: state.pathParameters['id']!)),
          ]),
          GoRoute(path: '/suppliers', name: 'suppliers', builder: (_, __) => const SupplierScreen()),
          GoRoute(path: '/cash', name: 'cash', builder: (_, __) => const CashManagementScreen()),
          GoRoute(path: '/expenses', name: 'expenses', builder: (_, __) => const ExpenseScreen()),
          GoRoute(path: '/reports', name: 'reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/team', name: 'team', builder: (_, __) => const TeamScreen()),
          GoRoute(path: '/settings', name: 'settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/coupons', name: 'coupons', builder: (_, __) => const CouponsScreen()),
          GoRoute(path: '/return-refund', name: 'returnRefund', builder: (_, __) => const ReturnRefundScreen()),
        ],
      ),
    ],
  );
});

class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          final loc = GoRouterState.of(context).matchedLocation;
          if (loc != '/dashboard') {
            context.go('/dashboard');
          }
        }
      },
      child: Scaffold(
        body: Row(children: [_NavigationRail(), Expanded(child: widget.child)]),
      ),
    );
  }
}

class _NavigationRail extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    int selectedIndex;
    if (location.startsWith('/dashboard')) selectedIndex = 0;
    else if (location.startsWith('/billing')) selectedIndex = 1;
    else if (location.startsWith('/inventory')) selectedIndex = 2;
    else if (location.startsWith('/customers')) selectedIndex = 3;
    else if (location.startsWith('/reports')) selectedIndex = 4;
    else if (location.startsWith('/settings') || location.startsWith('/coupons') || location.startsWith('/cash') || location.startsWith('/expenses') || location.startsWith('/team') || location.startsWith('/return-refund')) selectedIndex = 5;
    else selectedIndex = 0;

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        switch (i) {
          case 0: context.go('/dashboard');
          case 1: context.go('/billing');
          case 2: context.go('/inventory');
          case 3: context.go('/customers');
          case 4: context.go('/reports');
          case 5: context.go('/settings');
        }
      },
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
        NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Billing')),
        NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Inventory')),
        NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Customers')),
        NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Reports')),
        NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('More')),
      ],
    );
  }
}
