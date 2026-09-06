import 'package:flutter_test/flutter_test.dart';
import 'package:jaypos/core/utils/permission.dart';

void main() {
  group('PermissionChecker', () {
    test('super admin has all permissions', () {
      for (final permission in Permission.values) {
        expect(
          PermissionChecker.hasPermission(UserRole.superAdmin, permission),
          true,
          reason: 'Super admin should have $permission',
        );
      }
    });

    test('owner has billing permissions', () {
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.createBill), true);
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.viewBill), true);
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.refundBill), true);
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.discountOverride), true);
    });

    test('owner has inventory permissions', () {
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.addProduct), true);
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.editProduct), true);
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.deleteProduct), true);
    });

    test('owner has team management permissions', () {
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.addUser), true);
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.editUser), true);
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.deleteUser), true);
      expect(PermissionChecker.hasPermission(UserRole.owner, Permission.assignRole), true);
    });

    test('cashier has limited permissions', () {
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.createBill), true);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.viewBill), true);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.quickBill), true);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.viewProduct), true);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.viewCustomer), true);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.viewDashboard), true);
    });

    test('cashier does not have admin permissions', () {
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.addUser), false);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.addProduct), false);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.deleteProduct), false);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.editStoreProfile), false);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.backupRestore), false);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.discountOverride), false);
      expect(PermissionChecker.hasPermission(UserRole.cashier, Permission.voidBill), false);
    });

    test('manager has refund but not delete', () {
      expect(PermissionChecker.hasPermission(UserRole.manager, Permission.refundBill), true);
      expect(PermissionChecker.hasPermission(UserRole.manager, Permission.deleteProduct), false);
      expect(PermissionChecker.hasPermission(UserRole.manager, Permission.addUser), false);
    });

    test('admin has most but not all owner permissions', () {
      expect(PermissionChecker.hasPermission(UserRole.admin, Permission.addUser), false);
      expect(PermissionChecker.hasPermission(UserRole.admin, Permission.deleteUser), false);
      expect(PermissionChecker.hasPermission(UserRole.admin, Permission.assignRole), false);
      expect(PermissionChecker.hasPermission(UserRole.admin, Permission.createBill), true);
      expect(PermissionChecker.hasPermission(UserRole.admin, Permission.addProduct), true);
    });
  });
}
