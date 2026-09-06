import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../services/backup_service.dart';
import '../../../services/openwa_service.dart';
import '../../../services/printer_service.dart';
import '../../auth/controllers/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        data: (s) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SectionCard(theme: theme, icon: Icons.store, title: 'Store Profile', items: [
              _SettingItem(icon: Icons.edit, label: 'Edit Store Info', onTap: () => _editStoreDialog(context, ref, s)),
              _SettingItem(icon: Icons.percent, label: 'Tax Rate: ${s['tax_rate'] ?? s['default_tax_rate'] ?? '0'}%', onTap: () => _editTaxDialog(context, ref, s)),
              _SettingItem(icon: Icons.qr_code, label: 'UPI: ${s['upi_id'] ?? 'Not set'}', onTap: () => _editUpiDialog(context, ref, s)),
              _SettingItem(icon: Icons.palette, label: 'Receipt Template', onTap: () => context.pushNamed('receiptTemplate')),
              _SettingItem(icon: Icons.card_giftcard, label: 'Coupons', onTap: () => context.pushNamed('coupons')),
            ]),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(theme: theme, icon: Icons.print, title: 'Printer', items: [
              _SettingItem(icon: Icons.bluetooth, label: 'Scan Bluetooth Printer', onTap: () async {
                final printer = ref.read(printerServiceProvider);
                final devices = await printer.scanBluetoothPrinters();
                if (!context.mounted) return;
                if (devices.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Bluetooth printers found. Ensure printer is ON and paired.')));
                  return;
                }
                showDialog(context: context, builder: (d) => AlertDialog(
                  title: const Text('Available Printers'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    ...devices.map((dev) => ListTile(
                      leading: const Icon(Icons.bluetooth_connected),
                      title: Text(dev['name'] ?? ''),
                      subtitle: Text(dev['address'] ?? ''),
                      onTap: () async {
                        final p = ref.read(printerServiceProvider);
                        await p.connect(dev['address']!, name: dev['name'] ?? '');
                        Navigator.pop(d);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to ${dev['name']}'), backgroundColor: AppColors.success));
                      },
                    )),
                  ]),
                  actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel'))],
                ));
              }),
              _SettingItem(icon: Icons.article, label: ref.read(printerServiceProvider).isConnected
                ? 'Test Print (${ref.read(printerServiceProvider).deviceName})' : 'Test Print', onTap: () async {
                final p = ref.read(printerServiceProvider);
                if (!p.isConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect to a printer first')));
                  return;
                }
                final ok = await p.testPrint();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Test print sent' : 'Test print failed'), backgroundColor: ok ? AppColors.success : AppColors.danger));
              }),
            ]),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(theme: theme, icon: Icons.chat, title: 'WhatsApp (OpenWA)', items: [
              _SettingItem(icon: Icons.link, label: 'Server URL: ${s['openwa_url'] ?? 'http://localhost:3001'}', onTap: () async {
                final c = TextEditingController(text: s['openwa_url'] ?? 'http://localhost:3001');
                showDialog(context: context, builder: (d) => AlertDialog(
                  title: const Text('OpenWA Server URL'),
                  content: TextField(controller: c, decoration: const InputDecoration(labelText: 'http://host:port', hintText: 'http://192.168.1.100:3001')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () async {
                      final url = c.text.trim();
                      await ref.read(databaseProvider).setSetting('openwa_url', url);
                      ref.read(openwaServerUrlProvider.notifier).state = url;
                      ref.read(openwaServiceProvider).setBaseUrl(url);
                      ref.invalidate(settingsProvider);
                      Navigator.pop(d);
                    }, child: const Text('Save')),
                  ],
                ));
              }),
              _SettingItem(icon: Icons.phone_android, label: 'Connect with Phone Number', onTap: () async {
                final phoneC = TextEditingController();
                final connected = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
                  title: const Text('Connect WhatsApp'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Enter your WhatsApp number to start session:', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 12),
                    TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Phone number with country code', hintText: '919876543210'), keyboardType: TextInputType.phone),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Connect')),
                  ],
                ));
                if (connected == true && phoneC.text.trim().isNotEmpty) {
                  final wa = ref.read(openwaServiceProvider);
                  try {
                    final result = await wa.startSession(phone: phoneC.text.trim());
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result['message'] as String? ?? 'Session started. Check your WhatsApp for pairing code.'),
                      backgroundColor: AppColors.success,
                    ));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger));
                  }
                }
              }),
              _SettingItem(icon: Icons.info_outline, label: 'Session Status', onTap: () async {
                final wa = ref.read(openwaServiceProvider);
                final connected = await wa.checkHealth();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(connected ? 'OpenWA connected' : 'OpenWA not connected')));
              }),
              _SettingItem(icon: Icons.link_off, label: 'Disconnect', onTap: () {
                ref.read(openwaServiceProvider).disconnect();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OpenWA disconnected')));
              }),
            ]),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(theme: theme, icon: Icons.storage, title: 'Data', items: [
              _SettingItem(icon: Icons.backup, label: 'Backup', onTap: () async {
                final backup = ref.read(backupServiceProvider);
                try {
                  final path = await backup.createBackup();
                  if (!context.mounted) return;
                  await Share.shareXFiles([XFile(path)], text: 'JayPOS Backup');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved: $path'), backgroundColor: AppColors.success));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppColors.danger));
                }
              }),
              _SettingItem(icon: Icons.restore, label: 'Restore', onTap: () async {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place backup ZIP in app documents folder to restore')));
              }),
              _SettingItem(icon: Icons.delete_forever, label: 'Secure Erase', onTap: () async {
                final confirm = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
                  title: const Text('Secure Erase'),
                  content: const Text('This will permanently delete ALL local data (products, transactions, customers, settings). This cannot be undone!'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(d, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Erase Everything')),
                  ],
                ));
                if (confirm == true) {
                  await ref.read(databaseProvider).clearAllData();
                  ref.invalidate(settingsProvider);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: const Text('All data erased')));
                }
              }, textColor: AppColors.danger),
            ]),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(theme: theme, icon: Icons.subscriptions, title: 'Subscription', items: [
              _SettingItem(icon: Icons.info, label: 'Plan: ${s['plan'] ?? 'Growth'}', onTap: () {}),
              _SettingItem(icon: Icons.event, label: 'Expires: ${s['expires'] ?? 'Lifetime (Local)'}', onTap: () {}),
            ]),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(theme: theme, icon: Icons.info, title: 'About', items: [
              const _SettingItem(icon: Icons.tag, label: 'Version 1.0.0', onTap: null),
              _SettingItem(icon: Icons.logout, label: 'Sign Out', onTap: () {
                ref.read(authControllerProvider.notifier).logout();
                context.go('/login');
              }, textColor: AppColors.danger),
            ]),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _editStoreDialog(BuildContext ctx, WidgetRef ref, Map<String, String> s) {
    final nameC = TextEditingController(text: s['store_name'] ?? '');
    final addrC = TextEditingController(text: s['store_address'] ?? '');
    final phoneC = TextEditingController(text: s['store_phone'] ?? '');
    showDialog(context: ctx, builder: (d) => AlertDialog(
      title: const Text('Edit Store Info'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Store Name')),
        const SizedBox(height: 12),
        TextField(controller: addrC, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
        const SizedBox(height: 12),
        TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final db = ref.read(databaseProvider);
          if (nameC.text.trim().isNotEmpty) await db.setSetting('store_name', nameC.text.trim());
          if (addrC.text.trim().isNotEmpty) await db.setSetting('store_address', addrC.text.trim());
          if (phoneC.text.trim().isNotEmpty) await db.setSetting('store_phone', phoneC.text.trim());
          ref.invalidate(settingsProvider);
          Navigator.pop(d);
          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Store info updated')));
        }, child: const Text('Save')),
      ],
    ));
  }

  void _editTaxDialog(BuildContext ctx, WidgetRef ref, Map<String, String> s) {
    final c = TextEditingController(text: s['tax_rate'] ?? '0');
    showDialog(context: ctx, builder: (d) => AlertDialog(
      title: const Text('Tax Rate (%)'),
      content: TextField(controller: c, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Default Tax Rate')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          await ref.read(databaseProvider).setSetting('tax_rate', c.text.trim());
          ref.invalidate(settingsProvider);
          Navigator.pop(d);
        }, child: const Text('Save')),
      ],
    ));
  }

  void _editUpiDialog(BuildContext ctx, WidgetRef ref, Map<String, String> s) {
    final c = TextEditingController(text: s['upi_id'] ?? '');
    showDialog(context: ctx, builder: (d) => AlertDialog(
      title: const Text('UPI ID'),
      content: TextField(controller: c, decoration: const InputDecoration(labelText: 'UPI ID (e.g. store@paytm)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          await ref.read(databaseProvider).setSetting('upi_id', c.text.trim());
          ref.invalidate(settingsProvider);
          Navigator.pop(d);
        }, child: const Text('Save')),
      ],
    ));
  }
}

class _SectionCard extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String title;
  final List<_SettingItem> items;

  const _SectionCard({required this.theme, required this.icon, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: AppSpacing.sm), Text(title, style: theme.textTheme.titleMedium)]),
        const SizedBox(height: AppSpacing.sm),
        ...items.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: InkWell(
          onTap: item.onTap, borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Row(children: [
            Icon(item.icon, size: 18, color: item.textColor ?? AppColors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(item.label, style: TextStyle(color: item.textColor))),
            if (item.onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceVariant),
          ])),
        ))),
      ]),
    ));
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? textColor;
  const _SettingItem({required this.icon, required this.label, required this.onTap, this.textColor});
}
