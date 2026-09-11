import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// =========================================================================
// Database
// =========================================================================
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.e); // super parameter

  @override int get schemaVersion => 3;

  @override
  Iterable<TableInfo> get allTables => [];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => [];

  @override MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await _createAllTables();
      await _seedDefaults();
    },
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        await customStatement('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
      }
      if (from < 3) {
        // real-time UPI payment detection: transactions gain a status
        await customStatement("ALTER TABLE transactions ADD COLUMN status TEXT NOT NULL DEFAULT 'completed'");
        // txn_ref – transaction reference
        await customStatement('ALTER TABLE transactions ADD COLUMN txn_ref TEXT');
        // create indexes on statuses and txn_refs of transactions for effective search
        await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_txn_ref ON transactions(txn_ref)');
        // create new table `upi_payment_events`
        await customStatement('''
          CREATE TABLE IF NOT EXISTS upi_payment_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount INTEGER NOT NULL,
            reference TEXT DEFAULT '',
            txn_ref TEXT DEFAULT '',
            source TEXT DEFAULT 'notification',
            created_at TEXT NOT NULL,
            processed INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // processed: 0 – false, 1 – true
      }
    },
  );

  // ── raw SQL  ──────────────────────────────────────────────────────
  List<Variable> _toVars(List<Object?> p) =>
    p.map((e) => e == null ? const Variable<Object>(null) : Variable<Object>(e)).toList();

  Future<List<Map<String, dynamic>>> rawSelect(String sql, [List<Object?> p = const []]) async =>
    (await customSelect(sql, variables: _toVars(p)).get()).map((r) => r.data).toList();

  Future<int> rawInsert(String sql, [List<Object?> p = const []]) async =>
    customInsert(sql, variables: _toVars(p));

  Future<int> rawUpdate(String sql, [List<Object?> p = const []]) async =>
    customUpdate(sql, variables: _toVars(p));

  Future<int> rawDelete(String sql, [List<Object?> p = const []]) async {
    await customStatement(sql, p);
    return 0;
  }

  Future<void> _createAllTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL,
        display_name TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'cashier',
        is_active INTEGER NOT NULL DEFAULT 1, pin TEXT, biometric_enabled INTEGER NOT NULL DEFAULT 0,
        recovery_phrase_hash TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, description TEXT, created_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, contact_person TEXT, phone TEXT,
        email TEXT, address TEXT, gstin TEXT, notes TEXT, is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, sku TEXT NOT NULL UNIQUE, barcode TEXT,
        category_id TEXT, purchase_price INTEGER NOT NULL, sale_price INTEGER NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 0.0, tax_inclusive INTEGER NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0, low_stock_threshold INTEGER NOT NULL DEFAULT 10,
        image_path TEXT, supplier_id TEXT, description TEXT, is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT NOT NULL UNIQUE, email TEXT,
        address TEXT, loyalty_points INTEGER NOT NULL DEFAULT 0,
        total_spent INTEGER NOT NULL DEFAULT 0, visit_count INTEGER NOT NULL DEFAULT 0,
        last_visit TEXT, notes TEXT, is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY, invoice_no TEXT NOT NULL UNIQUE, transaction_type TEXT NOT NULL,
        customer_id TEXT, user_id TEXT NOT NULL, subtotal INTEGER NOT NULL,
        discount_amount INTEGER NOT NULL DEFAULT 0, discount_percent REAL NOT NULL DEFAULT 0.0,
        tax_amount INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL,
        round_off INTEGER NOT NULL DEFAULT 0, amount_paid INTEGER NOT NULL,
        change_amount INTEGER NOT NULL DEFAULT 0, coupon_code TEXT, notes TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed', txn_ref TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transaction_items (
        id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL, product_id TEXT NOT NULL,
        product_name TEXT NOT NULL, product_sku TEXT NOT NULL, quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL, tax_rate REAL NOT NULL, tax_inclusive INTEGER NOT NULL,
        line_total INTEGER NOT NULL, line_discount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL, method TEXT NOT NULL,
        amount INTEGER NOT NULL, reference TEXT, created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cash_flows (
        id TEXT PRIMARY KEY, type TEXT NOT NULL, amount INTEGER NOT NULL,
        reason TEXT, user_id TEXT NOT NULL, created_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY, category TEXT NOT NULL, amount INTEGER NOT NULL,
        description TEXT NOT NULL, notes TEXT, photo_path TEXT, user_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS stock_adjustments (
        id TEXT PRIMARY KEY, product_id TEXT NOT NULL, quantity_change INTEGER NOT NULL,
        reason TEXT NOT NULL, notes TEXT, user_id TEXT NOT NULL, created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS held_bills (
        id TEXT PRIMARY KEY, label TEXT, bill_data TEXT NOT NULL,
        user_id TEXT NOT NULL, held_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS loyalty_ledger (
        id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, points_change INTEGER NOT NULL,
        reason TEXT NOT NULL, transaction_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS returns (
        id TEXT PRIMARY KEY, original_transaction_id TEXT NOT NULL,
        total_refund_amount INTEGER NOT NULL, reason TEXT NOT NULL, user_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (original_transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS coupon_codes (
        id TEXT PRIMARY KEY, code TEXT NOT NULL UNIQUE, discount_type TEXT NOT NULL,
        discount_value INTEGER NOT NULL, min_bill_amount INTEGER NOT NULL DEFAULT 0,
        max_usage_count INTEGER NOT NULL DEFAULT 0, used_count INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1, expiry_date TEXT, created_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS coupon_redemptions (
        id TEXT PRIMARY KEY, coupon_id TEXT NOT NULL, transaction_id TEXT NOT NULL,
        discount_amount INTEGER NOT NULL, created_at TEXT NOT NULL,
        FOREIGN KEY (coupon_id) REFERENCES coupon_codes(id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS whatsapp_logs (
        id TEXT PRIMARY KEY, message_type TEXT NOT NULL, recipient_phone TEXT NOT NULL,
        message_content TEXT NOT NULL, is_sent INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS upi_payment_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        reference TEXT DEFAULT '',
        txn_ref TEXT DEFAULT '',
        source TEXT DEFAULT 'notification',
        created_at TEXT NOT NULL,
        processed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_transactions_txn_ref ON transactions(txn_ref)
    ''');
  }

  // ── USERS ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUser(String id) async {
    final r = await rawSelect('SELECT * FROM users WHERE id = ?', [id]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<Map<String, dynamic>?> getUserByUsername(String u) async {
    final r = await rawSelect('SELECT * FROM users WHERE username = ?', [u]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<List<Map<String, dynamic>>> getAllUsers() => rawSelect('SELECT * FROM users ORDER BY created_at DESC');
  Future<List<Map<String, dynamic>>> getActiveUsers() => rawSelect('SELECT * FROM users WHERE is_active = 1 ORDER BY display_name');
  Future<int> getUserCount() async {
    final r = await rawSelect('SELECT COUNT(*) as cnt FROM users');
    return (r.first['cnt'] as int);
  }
  Future<bool> isFirstUser() async => (await getUserCount()) == 0;
  Future<void> insertUser(Map<String, dynamic> u) async {
    await rawInsert(
      'INSERT INTO users (id, username, password_hash, display_name, role, is_active, pin, biometric_enabled, recovery_phrase_hash, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [u['id'], u['username'], u['password_hash'], u['display_name'], u['role'], u['is_active'] ?? 1, u['pin'], u['biometric_enabled'] ?? 0, u['recovery_phrase_hash'], u['created_at'], u['updated_at']],
    );
  }
  Future<void> updateUser(Map<String, dynamic> u) async {
    await rawUpdate(
      'UPDATE users SET username=?,password_hash=?,display_name=?,role=?,is_active=?,pin=?,biometric_enabled=?,recovery_phrase_hash=?,updated_at=? WHERE id=?',
      [u['username'], u['password_hash'], u['display_name'], u['role'], u['is_active'], u['pin'], u['biometric_enabled'], u['recovery_phrase_hash'], u['updated_at'], u['id']],
    );
  }
  Future<void> deleteUser(String id) async => rawDelete('DELETE FROM users WHERE id=?', [id]);

  // ── PRODUCTS ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getProduct(String id) async {
    final r = await rawSelect('SELECT * FROM products WHERE id=?', [id]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<Map<String, dynamic>?> getProductBySku(String sku) async {
    final r = await rawSelect('SELECT * FROM products WHERE sku=?', [sku]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<Map<String, dynamic>?> getProductByBarcode(String bc) async {
    final r = await rawSelect('SELECT * FROM products WHERE barcode=?', [bc]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<List<Map<String, dynamic>>> getAllProducts() => rawSelect('SELECT p.*,c.name as category_name,s.name as supplier_name FROM products p LEFT JOIN categories c ON c.id=p.category_id LEFT JOIN suppliers s ON s.id=p.supplier_id WHERE p.is_active=1 ORDER BY p.name');
  Future<List<Map<String, dynamic>>> searchProducts(String q) async {
    final p = '%$q%';
    return rawSelect('SELECT p.*,c.name as category_name FROM products p LEFT JOIN categories c ON c.id=p.category_id WHERE p.is_active=1 AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?) ORDER BY p.name LIMIT 50', [p, p, p]);
  }
  Future<List<Map<String, dynamic>>> getLowStockProducts() => rawSelect('SELECT * FROM products WHERE is_active=1 AND stock <= low_stock_threshold ORDER BY stock ASC');
  Future<void> insertProduct(Map<String, dynamic> p) async {
    await rawInsert(
      'INSERT INTO products (id,name,sku,barcode,category_id,purchase_price,sale_price,tax_rate,tax_inclusive,stock,low_stock_threshold,image_path,supplier_id,description,is_active,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [p['id'],p['name'],p['sku'],p['barcode'],p['category_id'],p['purchase_price'],p['sale_price'],p['tax_rate'],p['tax_inclusive']??0,p['stock']??0,p['low_stock_threshold']??10,p['image_path'],p['supplier_id'],p['description'],p['is_active']??1,p['created_at'],p['updated_at']],
    );
  }
  Future<void> updateProduct(Map<String, dynamic> p) async {
    await rawUpdate(
      'UPDATE products SET name=?,sku=?,barcode=?,category_id=?,purchase_price=?,sale_price=?,tax_rate=?,tax_inclusive=?,stock=?,low_stock_threshold=?,image_path=?,supplier_id=?,description=?,is_active=?,updated_at=? WHERE id=?',
      [p['name'],p['sku'],p['barcode'],p['category_id'],p['purchase_price'],p['sale_price'],p['tax_rate'],p['tax_inclusive'],p['stock'],p['low_stock_threshold'],p['image_path'],p['supplier_id'],p['description'],p['is_active'],p['updated_at'],p['id']],
    );
  }
  Future<void> updateStock(String id, int qty) async {
    await rawUpdate('UPDATE products SET stock=MAX(0,stock+?),updated_at=? WHERE id=?', [qty, DateTime.now().toIso8601String(), id]);
  }
  Future<void> deleteProduct(String id) async {
    await rawUpdate('UPDATE products SET is_active=0,updated_at=? WHERE id=?', [DateTime.now().toIso8601String(), id]);
  }
  Future<int> getProductCount() async {
    final r = await rawSelect('SELECT COUNT(*) as cnt FROM products WHERE is_active=1');
    return (r.first['cnt'] as int);
  }

  // ── CATEGORIES ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllCategories() => rawSelect('SELECT * FROM categories ORDER BY name');
  Future<void> insertCategory(Map<String, dynamic> c) async {
    await rawInsert('INSERT INTO categories (id,name,description,created_at) VALUES (?,?,?,?)', [c['id'],c['name'],c['description'],c['created_at']]);
  }

  // ── CUSTOMERS ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getCustomer(String id) async {
    final r = await rawSelect('SELECT * FROM customers WHERE id=?', [id]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<Map<String, dynamic>?> getCustomerByPhone(String phone) async {
    final r = await rawSelect('SELECT * FROM customers WHERE phone=?', [phone]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<List<Map<String, dynamic>>> getAllCustomers() => rawSelect('SELECT * FROM customers WHERE is_active=1 ORDER BY name');
  Future<List<Map<String, dynamic>>> searchCustomers(String q) async {
    final p = '%$q%';
    return rawSelect('SELECT * FROM customers WHERE is_active=1 AND (name LIKE ? OR phone LIKE ?) ORDER BY name LIMIT 20', [p, p]);
  }
  Future<void> insertCustomer(Map<String, dynamic> c) async {
    await rawInsert(
      'INSERT INTO customers (id,name,phone,email,address,loyalty_points,total_spent,visit_count,last_visit,notes,is_active,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [c['id'],c['name'],c['phone'],c['email'],c['address'],c['loyalty_points']??0,c['total_spent']??0,c['visit_count']??0,c['last_visit'],c['notes'],c['is_active']??1,c['created_at'],c['updated_at']],
    );
  }
  Future<void> updateCustomer(Map<String, dynamic> c) async {
    await rawUpdate(
      'UPDATE customers SET name=?,phone=?,email=?,address=?,loyalty_points=?,total_spent=?,visit_count=?,last_visit=?,notes=?,updated_at=? WHERE id=?',
      [c['name'],c['phone'],c['email'],c['address'],c['loyalty_points'],c['total_spent'],c['visit_count'],c['last_visit'],c['notes'],c['updated_at'],c['id']],
    );
  }
  Future<void> addLoyaltyPoints(String id, int points, String reason, String? txId, {int spentPaise = 0}) async {
    await transaction(() async {
      await rawUpdate('UPDATE customers SET loyalty_points=loyalty_points+?,total_spent=total_spent+?,visit_count=visit_count+1,last_visit=? WHERE id=?',
        [points, spentPaise, DateTime.now().toIso8601String(), id]);
      await rawInsert('INSERT INTO loyalty_ledger (id,customer_id,points_change,reason,transaction_id,created_at) VALUES (?,?,?,?,?,?)',
        ['ll-${DateTime.now().millisecondsSinceEpoch}', id, points, reason, txId, DateTime.now().toIso8601String()]);
    });
  }
  Future<void> redeemLoyaltyPoints(String id, int points, String? txId) async {
    await transaction(() async {
      await rawUpdate('UPDATE customers SET loyalty_points=MAX(0,loyalty_points-?) WHERE id=?', [points, id]);
      await rawInsert('INSERT INTO loyalty_ledger (id,customer_id,points_change,reason,transaction_id,created_at) VALUES (?,?,?,?,?,?)',
        ['ll-${DateTime.now().millisecondsSinceEpoch}', id, -points, 'redeemed', txId, DateTime.now().toIso8601String()]);
    });
  }

  // ── SUPPLIERS ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllSuppliers() => rawSelect('SELECT * FROM suppliers WHERE is_active=1 ORDER BY name');
  Future<Map<String, dynamic>?> getSupplier(String id) async {
    final r = await rawSelect('SELECT * FROM suppliers WHERE id=?', [id]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<void> insertSupplier(Map<String, dynamic> s) async {
    await rawInsert(
      'INSERT INTO suppliers (id,name,contact_person,phone,email,address,gstin,notes,is_active,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [s['id'],s['name'],s['contact_person'],s['phone'],s['email'],s['address'],s['gstin'],s['notes'],s['is_active']??1,s['created_at'],s['updated_at']],
    );
  }
  Future<void> updateSupplier(Map<String, dynamic> s) async {
    await rawUpdate(
      'UPDATE suppliers SET name=?,contact_person=?,phone=?,email=?,address=?,gstin=?,notes=?,is_active=?,updated_at=? WHERE id=?',
      [s['name'],s['contact_person'],s['phone'],s['email'],s['address'],s['gstin'],s['notes'],s['is_active'],s['updated_at'],s['id']],
    );
  }

  // ── TRANSACTIONS ──────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getTransaction(String id) async {
    final r = await rawSelect('SELECT * FROM transactions WHERE id=?', [id]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<Map<String, dynamic>?> getTransactionByInvoice(String inv) async {
    final r = await rawSelect('SELECT * FROM transactions WHERE invoice_no=?', [inv]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<List<Map<String, dynamic>>> getTransactions({int limit = 50, int offset = 0}) =>
    rawSelect('SELECT * FROM transactions ORDER BY created_at DESC LIMIT ? OFFSET ?', [limit, offset]);
  Future<List<Map<String, dynamic>>> getTransactionsByDate(DateTime start, DateTime end) =>
    rawSelect('SELECT * FROM transactions WHERE created_at >= ? AND created_at <= ? ORDER BY created_at DESC', [start.toIso8601String(), end.toIso8601String()]);
  Future<List<Map<String, dynamic>>> getTransactionItems(String txId) =>
    rawSelect('SELECT * FROM transaction_items WHERE transaction_id=?', [txId]);
  Future<List<Map<String, dynamic>>> getTransactionPayments(String txId) =>
    rawSelect('SELECT * FROM payments WHERE transaction_id=?', [txId]);

  /// [status] defaults to 'completed' to preserve existing cash/card behavior
  /// (stock, customer stats and coupon usage are applied immediately).
  /// Pass 'pending' for a UPI order awaiting real-time payment detection —
  /// in that case those side effects are deferred to [finalizePendingTransaction]
  /// so an abandoned/expired QR never touches stock or customer stats
  Future<Map<String, dynamic>> createTransaction(
    Map<String, dynamic> tx,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> payments, {
    String status = 'completed',
  }) async {
    late String id;
    await transaction(() async {
      id = tx['id'];
      await rawInsert(
        'INSERT INTO transactions (id,invoice_no,transaction_type,customer_id,user_id,subtotal,discount_amount,discount_percent,tax_amount,total,round_off,amount_paid,change_amount,coupon_code,notes,is_synced,created_at,updated_at,status,txn_ref) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [tx['id'],tx['invoice_no'],tx['transaction_type'],tx['customer_id'],tx['user_id'],tx['subtotal'],tx['discount_amount'],tx['discount_percent'],tx['tax_amount'],tx['total'],tx['round_off'],tx['amount_paid'],tx['change_amount'],tx['coupon_code'],tx['notes'],0,tx['created_at'],tx['updated_at'],status,tx['txn_ref']],
      );
      for (final it in items) {
        await rawInsert(
          'INSERT INTO transaction_items (id,transaction_id,product_id,product_name,product_sku,quantity,unit_price,tax_rate,tax_inclusive,line_total,line_discount) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
          [it['id'],id,it['product_id'],it['product_name'],it['product_sku'],it['quantity'],it['unit_price'],it['tax_rate'],it['tax_inclusive'],it['line_total'],it['line_discount']],
        );
        // "if the transaction still requires payment,
        // do nothing further with this item"
        if (status == 'pending') continue;
        final pid = it['product_id'] as String;
        if (pid != 'QUICK_BILL') {
          final updatedAt = DateTime.now().toIso8601String();
          final cur = await rawSelect('SELECT stock FROM products WHERE id=?', [pid]);
          final stock = (cur.isNotEmpty ? cur.first['stock'] as int : 0);
          final qty = it['quantity'] as int;
          if (stock < qty) throw Exception('Insufficient stock for ${it['product_name']}: have $stock, need $qty');
          await rawUpdate('UPDATE products SET stock=stock-?,updated_at=? WHERE id=?', [qty, updatedAt, pid]);
        }
      }
      for (final pay in payments) {
        await rawInsert(
          'INSERT INTO payments (id,transaction_id,method,amount,reference,created_at) VALUES (?,?,?,?,?,?)',
          [pay['id'],id,pay['method'],pay['amount'],pay['reference'],pay['created_at']],
        );
      }
      if (status == 'pending') return; // rest deferred to finalizePendingTransaction
      // Update customer stats
      if (tx['customer_id'] != null) {
        final now = DateTime.now().toIso8601String();
        await rawUpdate(
          'UPDATE customers SET total_spent=total_spent+?,visit_count=visit_count+1,last_visit=?,updated_at=? WHERE id=?',
          [tx['total'], now, now, tx['customer_id']],
        );
      }
      // Log coupon redemption
      if (tx['coupon_code'] != null && (tx['coupon_code'] as String).isNotEmpty) {
        final coupon = await getCouponByCode(tx['coupon_code'] as String);
        if (coupon != null) {
          final couponDiscount = tx['coupon_discount'] as int? ?? 0;
          await logCouponRedemption({
            'id': 'cr-${DateTime.now().millisecondsSinceEpoch}',
            'coupon_id': coupon['id'],
            'transaction_id': id,
            'discount_amount': couponDiscount,
            'created_at': tx['created_at'],
          });
          await incrementCouponUsage(tx['coupon_code'] as String);
        }
      }
    });
    return (await getTransaction(id))!;
  }

  Future<Map<String, dynamic>> createRefund(String origTxId, int amount, String reason, String userId) async {
    final id = 'ref-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    final items = await getTransactionItems(origTxId);
    final origTx = await getTransaction(origTxId);
    late Map<String, dynamic> result;
    await transaction(() async {
      // Insert refund record
      await rawInsert(
        'INSERT INTO returns (id,original_transaction_id,total_refund_amount,reason,user_id,created_at) VALUES (?,?,?,?,?,?)',
        [id, origTxId, amount, reason, userId, now],
      );
      // Restore stock for each returned item
      for (final it in items) {
        await rawUpdate('UPDATE products SET stock=stock+?,updated_at=? WHERE id=?',
          [it['quantity'], now, it['product_id']]);
      }
      // Reverse loyalty points earned on the original transaction
      if (origTx != null && origTx['customer_id'] != null) {
        final ledger = await rawSelect(
          'SELECT * FROM loyalty_ledger WHERE transaction_id=? AND reason=?',
          [origTxId, 'earned'],
        );
        for (final entry in ledger) {
          final reversalId = 'lr-${DateTime.now().millisecondsSinceEpoch}-${entry['id']}';
          await rawInsert(
            'INSERT INTO loyalty_ledger (id,customer_id,points_change,reason,transaction_id,created_at) VALUES (?,?,?,?,?,?)',
            [reversalId, entry['customer_id'], -(entry['points_change'] as int), 'refund_reversal', origTxId, now],
          );
        }
      }
      result = (await rawSelect('SELECT * FROM returns WHERE id=?', [id])).first;
    });
    return result;
  }

  // ── HELD BILLS ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHeldBills() =>
    rawSelect('SELECT * FROM held_bills ORDER BY held_at DESC');
  Future<void> holdBill(Map<String, dynamic> hb) async {
    await rawInsert('INSERT INTO held_bills (id,label,bill_data,user_id,held_at) VALUES (?,?,?,?,?)',
      [hb['id'], hb['label'], hb['bill_data'], hb['user_id'], hb['held_at']]);
  }
  Future<void> deleteHeldBill(String id) => rawDelete('DELETE FROM held_bills WHERE id=?', [id]);

  // ── SETTINGS ──────────────────────────────────────────────────────
  Future<String?> getSetting(String key) async {
    final r = await rawSelect('SELECT value FROM settings WHERE key=?', [key]);
    return r.isNotEmpty ? (r.first['value'] as String?) : null;
  }
  Future<void> setSetting(String key, String value) async {
    await rawInsert('INSERT OR REPLACE INTO settings (key,value,updated_at) VALUES (?,?,?)',
      [key, value, DateTime.now().toIso8601String()]);
  }
  Future<Map<String, String>> getAllSettings() async {
    final r = await rawSelect('SELECT * FROM settings');
    return {for (final row in r) row['key'] as String: row['value'] as String};
  }

  // ── CASH FLOW ─────────────────────────────────────────────────────
  Future<void> addCashFlow(Map<String, dynamic> cf) async {
    await rawInsert('INSERT INTO cash_flows (id,type,amount,reason,user_id,created_at) VALUES (?,?,?,?,?,?)',
      [cf['id'],cf['type'],cf['amount'],cf['reason'],cf['user_id'],cf['created_at']]);
  }
  Future<List<Map<String, dynamic>>> getCashFlows(DateTime date) =>
    rawSelect("SELECT * FROM cash_flows WHERE date(created_at)=date(?) ORDER BY created_at DESC", [date.toIso8601String()]);
  Future<int> getCashBalance() async {
    final r = await rawSelect("SELECT COALESCE(SUM(CASE WHEN type='in' OR type='open' THEN amount ELSE -amount END),0) as bal FROM cash_flows");
    return (r.first['bal'] as int);
  }

  // ── EXPENSES ──────────────────────────────────────────────────────
  Future<void> addExpense(Map<String, dynamic> e) async {
    await rawInsert('INSERT INTO expenses (id,category,amount,description,notes,photo_path,user_id,created_at) VALUES (?,?,?,?,?,?,?,?)',
      [e['id'],e['category'],e['amount'],e['description'],e['notes'],e['photo_path'],e['user_id'],e['created_at']]);
  }
  Future<List<Map<String, dynamic>>> getExpenses({int? month, int? year}) async {
    if (month != null && year != null) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);
      return rawSelect('SELECT * FROM expenses WHERE created_at>=? AND created_at<? ORDER BY created_at DESC', [start.toIso8601String(), end.toIso8601String()]);
    }
    return rawSelect('SELECT * FROM expenses ORDER BY created_at DESC LIMIT 50');
  }

  // ── STOCK ADJUSTMENTS ─────────────────────────────────────────────
  Future<void> addStockAdjustment(Map<String, dynamic> a) async {
    await transaction(() async {
      await rawInsert('INSERT INTO stock_adjustments (id,product_id,quantity_change,reason,notes,user_id,created_at) VALUES (?,?,?,?,?,?,?)',
        [a['id'],a['product_id'],a['quantity_change'],a['reason'],a['notes'],a['user_id'],a['created_at']]);
      await rawUpdate('UPDATE products SET stock=MAX(0,stock+?),updated_at=? WHERE id=?',
        [a['quantity_change'], DateTime.now().toIso8601String(), a['product_id']]);
    });
  }

  // ── COUPONS ───────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCoupons() => rawSelect('SELECT * FROM coupon_codes ORDER BY created_at DESC');
  Future<Map<String, dynamic>?> getCouponByCode(String code) async {
    final r = await rawSelect('SELECT * FROM coupon_codes WHERE code=?', [code]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<void> insertCoupon(Map<String, dynamic> c) async {
    await rawInsert('INSERT INTO coupon_codes (id,code,discount_type,discount_value,min_bill_amount,max_usage_count,used_count,is_active,expiry_date,created_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
      [c['id'],c['code'],c['discount_type'],c['discount_value'],c['min_bill_amount'],c['max_usage_count'],0,c['is_active']??1,c['expiry_date'],c['created_at']]);
  }
  Future<bool> redeemCoupon(String code, int billAmount) async {
    final c = await getCouponByCode(code);
    if (c == null) return false;
    if (c['is_active'] != 1) return false;
    if (c['expiry_date'] != null && DateTime.parse(c['expiry_date']!).isBefore(DateTime.now())) return false;
    if (c['max_usage_count'] > 0 && c['used_count'] >= c['max_usage_count']) return false;
    if ((c['min_bill_amount'] as int) > billAmount) return false;
    return true;
  }
  Future<void> incrementCouponUsage(String code) async {
    await rawUpdate('UPDATE coupon_codes SET used_count=used_count+1 WHERE code=?', [code]);
  }

  // ── RETURNS ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllReturns() =>
    rawSelect('SELECT r.*, t.invoice_no, u.display_name as user_name FROM returns r LEFT JOIN transactions t ON t.id=r.original_transaction_id LEFT JOIN users u ON u.id=r.user_id ORDER BY r.created_at DESC');
  Future<List<Map<String, dynamic>>> getReturnsByTransaction(String txId) =>
    rawSelect('SELECT * FROM returns WHERE original_transaction_id=?', [txId]);

  // ── LOYALTY LEDGER ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLoyaltyLedger(String customerId) =>
    rawSelect('SELECT * FROM loyalty_ledger WHERE customer_id=? ORDER BY created_at DESC', [customerId]);

  // ── COUPON REDEMPTIONS ──────────────────────────────────────────
  Future<void> logCouponRedemption(Map<String, dynamic> r) async {
    await rawInsert(
      'INSERT INTO coupon_redemptions (id,coupon_id,transaction_id,discount_amount,created_at) VALUES (?,?,?,?,?)',
      [r['id'], r['coupon_id'], r['transaction_id'], r['discount_amount'], r['created_at']]);
  }
  Future<List<Map<String, dynamic>>> getCouponRedemptions(String couponId) =>
    rawSelect('SELECT * FROM coupon_redemptions WHERE coupon_id=? ORDER BY created_at DESC', [couponId]);

  // ── STOCK ADJUSTMENTS ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStockAdjustments(String productId) =>
    rawSelect('SELECT sa.*, u.display_name as user_name FROM stock_adjustments sa LEFT JOIN users u ON u.id=sa.user_id WHERE sa.product_id=? ORDER BY sa.created_at DESC', [productId]);

  Future<List<Map<String, dynamic>>> getTransactionsByCustomer(String customerId) =>
    rawSelect('SELECT * FROM transactions WHERE customer_id=? ORDER BY created_at DESC', [customerId]);

  // ── SALES BY USER ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSalesByUser(DateTime start, DateTime end) =>
    rawSelect("SELECT u.id,u.display_name,COUNT(t.id) as tx_count,COALESCE(SUM(t.total),0) as total FROM users u LEFT JOIN transactions t ON t.user_id=u.id AND t.created_at>=? AND t.created_at<=? GROUP BY u.id ORDER BY total DESC",
      [start.toIso8601String(), end.toIso8601String()]);
  Future<List<Map<String, dynamic>>> getUserTransactionHistory(String userId, {int limit = 50}) =>
    rawSelect('SELECT * FROM transactions WHERE user_id=? ORDER BY created_at DESC LIMIT ?', [userId, limit]);

  // ── WHATSAPP LOGS ─────────────────────────────────────────────────
  Future<void> logWhatsApp(Map<String, dynamic> w) async {
    await rawInsert('INSERT INTO whatsapp_logs (id,message_type,recipient_phone,message_content,is_sent,is_synced,created_at) VALUES (?,?,?,?,?,?,?)',
      [w['id'],w['message_type'],w['recipient_phone'],w['message_content'],w['is_sent']??1,w['is_synced']??0,w['created_at']]);
  }
  Future<List<Map<String, dynamic>>> getUnsyncedLogs() =>
    rawSelect('SELECT * FROM whatsapp_logs WHERE is_synced=0');
  Future<void> markLogsSynced() => rawUpdate('UPDATE whatsapp_logs SET is_synced=1 WHERE is_synced=0');

  // ── DASHBOARD ─────────────────────────────────────────────────────
  Future<int> getTodaySales() async {
    final start = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
    final r = await rawSelect('SELECT COALESCE(SUM(total),0) as total FROM transactions WHERE created_at>=?', [start.toIso8601String()]);
    return (r.first['total'] as int);
  }
  Future<int> getTodayTransactionCount() async {
    final start = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
    final r = await rawSelect('SELECT COUNT(*) as cnt FROM transactions WHERE created_at>=?', [start.toIso8601String()]);
    return (r.first['cnt'] as int);
  }
  Future<List<Map<String, dynamic>>> getTopProducts(int limit) =>
    rawSelect(r"SELECT ti.product_id,ti.product_name,SUM(ti.quantity) as qty,SUM(ti.line_total) as total FROM transaction_items ti JOIN transactions t ON t.id=ti.transaction_id WHERE t.id NOT IN (SELECT original_transaction_id FROM returns) GROUP BY ti.product_id ORDER BY qty DESC LIMIT ?", [limit]);
  Future<List<Map<String, dynamic>>> getDailySalesForWeek() async {
    final now = DateTime.now();
    final weekday = now.weekday; // Mon=1, Sun=7
    final monday = now.subtract(Duration(days: weekday - 1)).copyWith(hour: 0, minute: 0, second: 0);
    final r = await rawSelect(
      "SELECT CAST(STRFTIME('%w', created_at) AS INTEGER) as dow, COALESCE(SUM(total),0) as total FROM transactions WHERE created_at>=? AND created_at<? GROUP BY dow ORDER BY dow",
      [monday.toIso8601String(), now.add(const Duration(days: 1)).toIso8601String()],
    );
    return r;
  }

  Future<List<Map<String, dynamic>>> getTaxSummary() async {
    return rawSelect(
      "SELECT ti.tax_rate,"
      "SUM(CASE WHEN ti.tax_inclusive=1 THEN ti.line_total - CAST(ROUND(ti.line_total*100.0/(100+ti.tax_rate)) AS INTEGER) ELSE CAST(ROUND(ti.line_total*ti.tax_rate/100.0) AS INTEGER) END) as tax "
      "FROM transaction_items ti JOIN transactions t ON t.id=ti.transaction_id "
      "WHERE ti.tax_rate>0 GROUP BY ti.tax_rate ORDER BY ti.tax_rate",
    );
  }

  // ── REPORTS ───────────────────────────────────────────────────────
  Future<int> getMonthSales(int month, int year) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final r = await rawSelect('SELECT COALESCE(SUM(total),0) as total FROM transactions WHERE created_at>=? AND created_at<?', [start.toIso8601String(), end.toIso8601String()]);
    return (r.first['total'] as int);
  }
  Future<List<Map<String, dynamic>>> getSalesByDay(DateTime start, DateTime end) =>
    rawSelect("SELECT date(created_at) as day,COUNT(*) as count,SUM(total) as total FROM transactions WHERE created_at>=? AND created_at<=? GROUP BY day ORDER BY day", [start.toIso8601String(), end.toIso8601String()]);
  Future<List<Map<String, dynamic>>> getSalesByPaymentMethod(DateTime start, DateTime end) =>
    rawSelect("SELECT p.method,COUNT(*) as count,SUM(p.amount) as total FROM payments p JOIN transactions t ON t.id=p.transaction_id WHERE t.created_at>=? AND t.created_at<=? GROUP BY p.method", [start.toIso8601String(), end.toIso8601String()]);
  Future<List<Map<String, dynamic>>> getPaymentSummary() async {
    final r = await rawSelect(r"SELECT p.method as payment_method,SUM(p.amount) as total FROM payments p JOIN transactions t ON t.id=p.transaction_id WHERE t.id NOT IN (SELECT original_transaction_id FROM returns) GROUP BY p.method ORDER BY total DESC");
    return r;
  }

  // ── SEED ──────────────────────────────────────────────────────────
  Future<void> _seedDefaults() async {
    final r = await rawSelect('SELECT COUNT(*) as cnt FROM settings');
    if (r.isNotEmpty && (r.first['cnt'] as int) == 0) {
      final now = DateTime.now().toIso8601String();
      for (final e in {
        'store_name': 'My Store', 'store_address': '', 'store_phone': '',
        'store_gstin': '', 'currency_symbol': '₹', 'default_tax_rate': '0.0',
        'upi_id': '', 'printer_width': '58', 'receipt_header': 'Thank you for your visit!',
        'receipt_footer': 'Visit Again!', 'receipt_show_logo': 'true',
        'loyalty_enabled': 'true', 'loyalty_spend_per_point': '10000',
        'loyalty_point_value': '100',
      }.entries) {
        await rawInsert('INSERT OR IGNORE INTO settings (key,value,updated_at) VALUES (?,?,?)', [e.key, e.value, now]);
      }
    }
  }

  Future<void> clearAllData() async {
    await customStatement('DELETE FROM transaction_items', []);
    await customStatement('DELETE FROM payments', []);
    await customStatement('DELETE FROM transactions', []);
    await customStatement('DELETE FROM products', []);
    await customStatement('DELETE FROM customers', []);
    await customStatement('DELETE FROM suppliers', []);
    await customStatement('DELETE FROM categories', []);
    await customStatement('DELETE FROM coupons', []);
    await customStatement('DELETE FROM stock_adjustments', []);
    await customStatement('DELETE FROM expense_categories', []);
    await customStatement('DELETE FROM expenses', []);
    await customStatement('DELETE FROM cash_register', []);
    await customStatement('DELETE FROM team_members', []);
    await customStatement('DELETE FROM settings', []);
    await customStatement('DELETE FROM loyalty_ledger', []);
    await customStatement('DELETE FROM coupon_usage', []);
    await customStatement('DELETE FROM return_items', []);
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'jaypos.db'));
    return NativeDatabase(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase(_openConnection()));
