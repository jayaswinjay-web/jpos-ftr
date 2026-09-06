enum UserRole {
  superAdmin,
  owner,
  admin,
  manager,
  cashier,
}

enum PaymentMethod {
  cash,
  upi,
  card,
  split,
  loyalty,
}

enum TransactionType {
  sale,
  refund,
  quickSale,
}

enum ExpenseCategory {
  rent,
  salary,
  utilities,
  stockPurchase,
  maintenance,
  marketing,
  misc,
}

enum StockAdjustmentReason {
  damaged,
  expired,
  theft,
  correction,
  returned,
  received,
}

enum CouponDiscountType {
  flat,
  percentage,
}

enum PlanTier {
  starter,
  growth,
  pro,
}

enum SubscriptionStatus {
  active,
  expired,
  suspended,
  cancelled,
}
