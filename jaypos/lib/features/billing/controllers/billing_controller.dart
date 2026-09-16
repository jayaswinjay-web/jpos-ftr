import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/invoice.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/upi.dart';
import '../../../data/local/database.dart';

/// A UPI order that has been created as `pending` and is waiting for payment.
class PendingUpiOrder {
  const PendingUpiOrder({
    required this.transactionId,
    required this.invoiceNo,
    required this.txnRef,
    required this.amountPaise,
    required this.upiPayString,
  });

  final String transactionId;
  final String invoiceNo;
  final String txnRef;
  final int amountPaise;
  final String upiPayString;
}

class CartItem {
  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    this.taxRate = 0,
    this.taxInclusive = false,
    this.lineDiscount = 0,
  });

  final String id;
  final String productId;
  String name;
  String sku;
  int unitPrice;
  int quantity;
  double taxRate;
  bool taxInclusive;
  int lineDiscount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'product_name': name,
        'product_sku': sku,
        'unit_price': unitPrice,
        'quantity': quantity,
        'tax_rate': taxRate,
        'tax_inclusive': taxInclusive ? 1 : 0,
        'line_total': lineTotal,
        'line_discount': lineDiscount,
      };

  int get lineTotal {
    final base = unitPrice * quantity;
    if (taxInclusive) {
      final money = Money(base);
      final exTax = money.taxInclusiveBackout(taxRate);
      return exTax.paise - lineDiscount;
    }
    return base - lineDiscount;
  }

  int get taxAmount {
    final line = Money(unitPrice * quantity);
    if (taxInclusive) {
      return line.paise - line.taxInclusiveBackout(taxRate).paise;
    }
    return line.taxAmount(taxRate).paise;
  }
}

class BillingState {
  const BillingState({
    this.items = const [],
    this.billDiscount = 0,
    this.billDiscountPercent = 0,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.paymentMethod = 'cash',
    this.couponCode,
    this.couponDiscount = 0,
    this.notes,
    this.loyaltyRedeemPoints = 0,
    this.loyaltyRedeemPaise = 0,
  });

  final List<CartItem> items;
  final int billDiscount;
  final double billDiscountPercent;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String paymentMethod;
  final String? couponCode;
  final int couponDiscount;
  final String? notes;
  final int loyaltyRedeemPoints;
  final int loyaltyRedeemPaise;

  BillingState copyWith({
    List<CartItem>? items,
    int? billDiscount,
    double? billDiscountPercent,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? paymentMethod,
    String? couponCode,
    int? couponDiscount,
    String? notes,
    int? loyaltyRedeemPoints,
    int? loyaltyRedeemPaise,
  }) =>
      BillingState(
        items: items ?? this.items,
        billDiscount: billDiscount ?? this.billDiscount,
        billDiscountPercent: billDiscountPercent ?? this.billDiscountPercent,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        couponCode: couponCode ?? this.couponCode,
        couponDiscount: couponDiscount ?? this.couponDiscount,
        notes: notes ?? this.notes,
        loyaltyRedeemPoints: loyaltyRedeemPoints ?? this.loyaltyRedeemPoints,
        loyaltyRedeemPaise: loyaltyRedeemPaise ?? this.loyaltyRedeemPaise,
      );

  int get subtotal => items.fold(0, (sum, i) => sum + i.unitPrice * i.quantity);

  int get taxAmount {
    var total = 0;
    for (final item in items) {
      final line = Money(item.unitPrice * item.quantity);
      if (item.taxInclusive) {
        total += line.paise - line.taxInclusiveBackout(item.taxRate).paise;
      } else {
        total += line.taxAmount(item.taxRate).paise;
      }
    }
    return total;
  }

  int get total => subtotal + taxAmount - billDiscount - couponDiscount;
  int get grandTotal => total - loyaltyRedeemPaise;
}

class BillingController extends StateNotifier<BillingState> {
  BillingController(this._db) : super(const BillingState());
  final AppDatabase _db;

  void addItem(Map<String, dynamic> product) {
    final item = CartItem(
      id: const Uuid().v4(),
      productId: product['id'] as String,
      name: product['name'] as String,
      sku: product['sku'] as String,
      unitPrice: (product['sale_price'] as int),
      quantity: 1,
      taxRate: (product['tax_rate'] as num).toDouble(),
      taxInclusive: (product['tax_inclusive'] as int) == 1,
    );
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeItem(int index) {
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items);
  }

  void updateQty(int index, int delta) {
    final items = [...state.items];
    items[index].quantity = (items[index].quantity + delta).clamp(1, 999);
    state = state.copyWith(items: items);
  }

  void setDiscount(double percent) {
    final capped = percent.clamp(0, 50);
    final discount = Money(state.subtotal).percentage(capped.toDouble());
    state = state.copyWith(
        billDiscountPercent: capped.toDouble(), billDiscount: discount.paise,);
  }

  void setCustomer(Map<String, dynamic>? customer) {
    state = state.copyWith(
      customerId: customer?['id'] as String?,
      customerName: customer?['name'] as String?,
      customerPhone: customer?['phone'] as String?,
    );
  }

  void setCustomerPhone(String phone) {
    state = state.copyWith(customerPhone: phone);
  }

  void setPaymentMethod(String method) =>
      state = state.copyWith(paymentMethod: method);

  Future<void> setCoupon(String? code) async {
    if (code == null || code.isEmpty) {
      state = state.copyWith(couponDiscount: 0);
      return;
    }
    final coupon = await _db.getCouponByCode(code);
    if (coupon == null) {
      state = state.copyWith(couponDiscount: 0);
      return;
    }
    final discountType = coupon['discount_type'] as String;
    final discountValue = coupon['discount_value'] as int;
    final subtotal = state.subtotal;
    var discount = 0;
    if (discountType == 'flat') {
      discount = discountValue;
    } else if (discountType == 'percent') {
      discount = Money(subtotal).percentage(discountValue.toDouble()).paise;
    }
    if (discount > subtotal) discount = subtotal;
    state = state.copyWith(couponCode: code, couponDiscount: discount);
  }

  void setLoyaltyRedeem(int points, int paise) => state =
      state.copyWith(loyaltyRedeemPoints: points, loyaltyRedeemPaise: paise);

  void clearLoyaltyRedeem() =>
      state = state.copyWith(loyaltyRedeemPoints: 0, loyaltyRedeemPaise: 0);

  void setNotes(String? notes) => state = state.copyWith(notes: notes);

  void clearCart() => state = const BillingState();

  Future<Map<String, dynamic>?> checkout(String userId) async {
    if (state.items.isEmpty) return null;
    final now = DateTime.now();
    final txId = const Uuid().v4();
    final invoiceNo = InvoiceGenerator.generate();

    final items = state.items
        .map((i) => {
              'id': const Uuid().v4(),
              'product_id': i.productId,
              'product_name': i.name,
              'product_sku': i.sku,
              'quantity': i.quantity,
              'unit_price': i.unitPrice,
              'tax_rate': i.taxRate,
              'tax_inclusive': i.taxInclusive ? 1 : 0,
              'line_total': i.lineTotal,
              'line_discount': i.lineDiscount,
            },)
        .toList();

    final finalTotal = state.grandTotal;
    final payments = [
      {
        'id': const Uuid().v4(),
        'method': state.paymentMethod,
        'amount': finalTotal,
        'reference': null,
        'created_at': now.toIso8601String(),
      }
    ];

    final tx = {
      'id': txId,
      'invoice_no': invoiceNo,
      'transaction_type': 'sale',
      'customer_id': state.customerId,
      'user_id': userId,
      'subtotal': state.subtotal,
      'discount_amount': state.billDiscount,
      'discount_percent': state.billDiscountPercent,
      'tax_amount': state.taxAmount,
      'total': finalTotal,
      'round_off': 0,
      'amount_paid': finalTotal,
      'change_amount': 0,
      'coupon_code': state.couponCode,
      'coupon_discount': state.couponDiscount,
      'notes': state.notes,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    try {
      final result = await _db.createTransaction(tx, items, payments);

      // Update customer loyalty
      if (state.customerId != null) {
        await _db.addLoyaltyPoints(
            state.customerId!, finalTotal ~/ 100, 'earned', txId,
            spentPaise: finalTotal,);
      }

      // Redeem loyalty points if any
      if (state.loyaltyRedeemPoints > 0 && state.customerId != null) {
        await _db.redeemLoyaltyPoints(
            state.customerId!, state.loyaltyRedeemPoints, txId,);
      }

      clearCart();
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Creates a pending UPI transaction and returns it together with the
  /// `upi://pay` string for the dynamic QR

  /// Unlike [checkout], nothing is committed yet: stock, loyalty and coupon
  /// usage are all deferred until the payment is actually detected (or the
  /// merchant confirms manually), so an abandoned QR leaves no trace beyond a
  /// pending row that can be cancelled. The cart is intentionally not
  /// cleared here — it stays on screen until the bill flips to PAID
  Future<PendingUpiOrder?> createPendingUpiOrder(
    String userId, {
    required String upiId,
    required String payeeName,
  }) async {
    if (state.items.isEmpty) return null;
    final now = DateTime.now();
    final txId = const Uuid().v4();
    final invoiceNo = InvoiceGenerator.generate();
    final txnRef = Upi.generateTxnRefAuto(at: now);

    final items = state.items
        .map((i) => {
              'id': const Uuid().v4(),
              'product_id': i.productId,
              'product_name': i.name,
              'product_sku': i.sku,
              'quantity': i.quantity,
              'unit_price': i.unitPrice,
              'tax_rate': i.taxRate,
              'tax_inclusive': i.taxInclusive ? 1 : 0,
              'line_total': i.lineTotal,
              'line_discount': i.lineDiscount,
            },)
        .toList();

    final finalTotal = state.grandTotal;
    final tx = {
      'id': txId,
      'invoice_no': invoiceNo,
      'transaction_type': 'sale',
      'customer_id': state.customerId,
      'user_id': userId,
      'subtotal': state.subtotal,
      'discount_amount': state.billDiscount,
      'discount_percent': state.billDiscountPercent,
      'tax_amount': state.taxAmount,
      'total': finalTotal,
      'round_off': 0,
      'amount_paid': 0, // nothing received yet
      'change_amount': 0,
      'coupon_code': state.couponCode,
      'coupon_discount': state.couponDiscount,
      'notes': state.notes,
      'txn_ref': txnRef,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    try {
      // No payment rows yet — the payment is inserted on finalization
      await _db.createTransaction(tx, items, const [], status: 'pending');
      return PendingUpiOrder(
        transactionId: txId,
        invoiceNo: invoiceNo,
        txnRef: txnRef,
        amountPaise: finalTotal,
        upiPayString: Upi.buildPayString(
          upiId: upiId,
          payeeName: payeeName,
          amountPaise: finalTotal,
          txnRef: txnRef,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Flips a pending UPI order to PAID
  /// Used by both the automatic notification match and the manual "Payment Received" fallback
  Future<Map<String, dynamic>?> finalizeUpiOrder(
    String txId, {
    String? reference,
  }) async {
    try {
      final result = await _db.finalizePendingTransaction(
        txId,
        method: 'upi',
        reference: reference,
      );
      final total = result['total'] as int;
      final customerId = result['customer_id'] as String?;
      if (customerId != null) {
        await _db.addLoyaltyPoints(
          customerId,
          total ~/ 100,
          'earned',
          txId,
          spentPaise: total,
        );
        if (state.loyaltyRedeemPoints > 0) {
          await _db.redeemLoyaltyPoints(
            customerId,
            state.loyaltyRedeemPoints,
            txId,
          );
        }
      }
      clearCart();
      return result;
    } catch (e) {
      return null;
    }
  }

  

  Future<void> holdBill(String userId) async {
    final data = {
      'items': state.items.map((i) => i.toMap()).toList(),
      'customer_id': state.customerId,
      'customer_phone': state.customerPhone,
      'payment_method': state.paymentMethod,
      'notes': state.notes,
    };
    await _db.holdBill({
      'id': const Uuid().v4(),
      'label': 'Bill #${state.items.length} items',
      'bill_data': jsonEncode(data),
      'user_id': userId,
      'held_at': DateTime.now().toIso8601String(),
    });
    clearCart();
  }

  Future<List<Map<String, dynamic>>> getHeldBills() => _db.getHeldBills();

  Future<void> restoreHeldBill(String billData) async {
    final data = jsonDecode(billData) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((i) => CartItem(
              id: i['id'] as String,
              productId: i['product_id'] as String,
              name: i['product_name'] as String,
              sku: i['product_sku'] as String,
              unitPrice: i['unit_price'] as int,
              quantity: i['quantity'] as int,
              taxRate: (i['tax_rate'] as num).toDouble(),
              taxInclusive: (i['tax_inclusive'] as int) == 1,
              lineDiscount: i['line_discount'] as int? ?? 0,
            ),)
        .toList();
    state = BillingState(
      items: items,
      customerPhone: data['customer_phone'] as String?,
      paymentMethod: data['payment_method'] as String? ?? 'cash',
      notes: data['notes'] as String?,
    );
  }
}

final billingControllerProvider =
    StateNotifierProvider<BillingController, BillingState>((ref) {
  return BillingController(ref.watch(databaseProvider));
});
