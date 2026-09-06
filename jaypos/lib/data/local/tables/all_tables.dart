import 'package:drift/drift.dart';

class UsersTable extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get pin => text().nullable()();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get recoveryPhraseHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}

class ProductsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().unique()();
  TextColumn get barcode => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get purchasePrice => integer()();
  IntColumn get salePrice => integer()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  BoolColumn get taxInclusive => boolean().withDefault(const Constant(false))();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(10))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get supplierId => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
  @override List<String> get customConstraints => [
    'FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL',
    'FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL',
  ];
}

class CategoriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}

class CustomersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().unique()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  IntColumn get loyaltyPoints => integer().withDefault(const Constant(0))();
  IntColumn get totalSpent => integer().withDefault(const Constant(0))();
  IntColumn get visitCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastVisit => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}

class SuppliersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get gstin => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}

class TransactionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNo => text().unique()();
  TextColumn get transactionType => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get userId => text()();
  IntColumn get subtotal => integer()();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  IntColumn get taxAmount => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  IntColumn get roundOff => integer().withDefault(const Constant(0))();
  IntColumn get amountPaid => integer()();
  IntColumn get changeAmount => integer().withDefault(const Constant(0))();
  TextColumn get couponCode => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
  @override List<String> get customConstraints => [
    'FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL',
    'FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT',
  ];
}

class TransactionItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  TextColumn get productSku => text()();
  IntColumn get quantity => integer()();
  IntColumn get unitPrice => integer()();
  RealColumn get taxRate => real()();
  BoolColumn get taxInclusive => boolean()();
  IntColumn get lineTotal => integer()();
  IntColumn get lineDiscount => integer().withDefault(const Constant(0))();
  @override Set<Column> get primaryKey => {id};
  @override List<String> get customConstraints => [
    'FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE',
    'FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT',
  ];
}

class PaymentsTable extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get method => text()();
  IntColumn get amount => integer()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
  @override List<String> get customConstraints => [
    'FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE',
  ];
}

class CashFlowsTable extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  IntColumn get amount => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}

class ExpensesTable extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  IntColumn get amount => integer()();
  TextColumn get description => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}

class StockAdjustmentsTable extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  IntColumn get quantityChange => integer()();
  TextColumn get reason => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
  @override List<String> get customConstraints => [
    'FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT',
  ];
}

class HeldBillsTable extends Table {
  TextColumn get id => text()();
  TextColumn get label => text().nullable()();
  TextColumn get billData => text()();
  TextColumn get userId => text()();
  DateTimeColumn get heldAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}

class SettingsTable extends Table {
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {key};
}

class LoyaltyLedgerTable extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  IntColumn get pointsChange => integer()();
  TextColumn get reason => text()();
  TextColumn get transactionId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
  @override List<String> get customConstraints => [
    'FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE',
    'FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL',
  ];
}

class ReturnsTable extends Table {
  TextColumn get id => text()();
  TextColumn get originalTransactionId => text()();
  IntColumn get totalRefundAmount => integer()();
  TextColumn get reason => text()();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
  @override List<String> get customConstraints => [
    'FOREIGN KEY (original_transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT',
  ];
}

class CouponCodesTable extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()();
  TextColumn get discountType => text()();
  IntColumn get discountValue => integer()();
  IntColumn get minBillAmount => integer().withDefault(const Constant(0))();
  IntColumn get maxUsageCount => integer().withDefault(const Constant(0))();
  IntColumn get usedCount => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}

class CouponRedemptionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get couponId => text()();
  TextColumn get transactionId => text()();
  IntColumn get discountAmount => integer()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
  @override List<String> get customConstraints => [
    'FOREIGN KEY (coupon_id) REFERENCES coupon_codes(id) ON DELETE CASCADE',
    'FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE',
  ];
}

class WhatsAppLogsTable extends Table {
  TextColumn get id => text()();
  TextColumn get messageType => text()();
  TextColumn get recipientPhone => text()();
  TextColumn get messageContent => text()();
  BoolColumn get isSent => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};
}
