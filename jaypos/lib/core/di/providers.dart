import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/local/database.dart';
export '../../data/local/database.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
  headers: {'Content-Type': 'application/json'},
)));

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Initialize before use'));

final sharedPrefsFutureProvider = FutureProvider<SharedPreferences>((ref) async {
  final p = await SharedPreferences.getInstance();
  return p;
});

// ── DB-backed providers ──────────────────────────────────────────────
final todaySalesProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getTodaySales();
});

final todayTxCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getTodayTransactionCount();
});

final activeUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getActiveUsers();
});

final allProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllProducts();
});

final lowStockProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getLowStockProducts();
});

final topProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getTopProducts(5);
});

final allCustomersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllCustomers();
});

final allSuppliersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllSuppliers();
});

final allCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllCategories();
});

final recentTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getTransactions();
});

final heldBillsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getHeldBills();
});

final settingsProvider = FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllSettings();
});

final weekSalesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getDailySalesForWeek();
});
