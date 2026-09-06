import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/local/database.dart';
import '../../../core/utils/permission.dart';

final allUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllUsers();
});

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});
  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final _nameC = TextEditingController();
  final _userC = TextEditingController();
  final _passC = TextEditingController();
  String _role = 'cashier';

  @override
  void dispose() { _nameC.dispose(); _userC.dispose(); _passC.dispose(); super.dispose(); }

  void _showAddUserSheet() {
    _nameC.clear(); _userC.clear(); _passC.clear(); _role = 'cashier';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add Staff', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Display Name *')),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _userC, decoration: const InputDecoration(labelText: 'Username *')),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _passC, decoration: const InputDecoration(labelText: 'Password *'), obscureText: true),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Role'),
              value: _role,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
              ],
              onChanged: (v) { if (v != null) setSheetState(() => _role = v); },
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 48, child: ElevatedButton(onPressed: () async {
              if (_nameC.text.trim().isEmpty || _userC.text.trim().isEmpty || _passC.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('All fields required')));
                return;
              }
              final hash = sha256.convert(utf8.encode(_passC.text.trim())).toString();
              await ref.read(databaseProvider).insertUser({
                'id': Uuid().v4(),
                'username': _userC.text.trim(),
                'password_hash': hash,
                'display_name': _nameC.text.trim(),
                'role': _role,
                'is_active': 1,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
              ref.invalidate(allUsersProvider);
              Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff added')));
            }, child: const Text('Add Staff'))),
            const SizedBox(height: AppSpacing.lg),
          ]),
        ),
      ),
    );
  }

  UserRole _parseRole(String? r) {
    switch (r) {
      case 'owner': return UserRole.owner;
      case 'admin': return UserRole.admin;
      case 'manager': return UserRole.manager;
      case 'cashier': return UserRole.cashier;
      default: return UserRole.cashier;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final users = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: users.when(
        data: (list) => list.isEmpty
          ? const Center(child: Text('No staff members'))
          : ListView.builder(padding: const EdgeInsets.all(AppSpacing.md), itemCount: list.length,
              itemBuilder: (_, i) => _userCard(theme, list[i])),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddUserSheet, child: const Icon(Icons.person_add)),
    );
  }

  Widget _userCard(ThemeData theme, Map<String, dynamic> u) {
    final role = _parseRole(u['role'] as String?);
    return Card(margin: const EdgeInsets.only(bottom: AppSpacing.sm), child: ListTile(
      leading: CircleAvatar(
        backgroundColor: role == UserRole.owner ? AppColors.warningContainer : AppColors.primaryContainer,
        child: Icon(role == UserRole.owner ? Icons.star : Icons.person,
            color: role == UserRole.owner ? AppColors.warning : AppColors.primary),
      ),
      title: Text(u['display_name'] as String? ?? u['username'] as String),
      subtitle: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Text(role.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.primary))),
        const SizedBox(width: AppSpacing.sm),
        Text('Active', style: const TextStyle(fontSize: 12, color: AppColors.success)),
      ]),
      trailing: PopupMenuButton(itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
        const PopupMenuItem(value: 'disable', child: Text('Disable')),
        const PopupMenuItem(value: 'sales', child: Text('View Sales')),
      ], onSelected: (v) async {
        if (v == 'disable') {
          final db = ref.read(databaseProvider);
          final isActive = u['is_active'] == 1;
          await db.rawUpdate('UPDATE users SET is_active=? WHERE id=?', [isActive ? 0 : 1, u['id']]);
          ref.invalidate(allUsersProvider);
        } else if (v == 'edit') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit coming soon')));
        } else if (v == 'reset') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset coming soon')));
        } else if (v == 'sales') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('View Sales coming soon')));
        }
      }),
      isThreeLine: true,
    ));
  }
}
