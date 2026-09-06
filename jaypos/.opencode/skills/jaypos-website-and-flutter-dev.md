---
name: jaypos-dev
description: Skills for JayPOS project — Flutter POS app and marketing website development, design, and deployment
---

# JayPOS Development Skills

## Website (index.html)

### Location
`jaypos/website/index.html` — single-page marketing site, hosted on GitHub Pages.

### Color Palette (current)
- Dark sections: `#1a1d23` (warm charcoal)
- Light sections: `#f4f5f7` (warm off-white)
- Accent: `#f59e0b` (amber) — used for buttons, highlights, icons
- Text on dark: `#e5e7eb`, muted: `#9ca3af`
- Text on light: `#1e2938`, muted: `#6b7280`
- White cards: `#ffffff`
- Footer: `#14161b`

### Design Rules
- **NO purple**, **NO dark navy**, **NO glassmorphism**, **NO neumorphism**, **NO trendy effects**
- Clean corporate feel with balanced dark/light sections
- Alternating section rhythm: dark → light → dark → light → white → light → dark
- Amber as the single accent color (professional warm energy)
- Simple borders, subtle shadows — no blurs or gradients
- Inter font family

### Mobile Optimizations (added 27 June 2026)
- Hamburger menu replaces nav links on screens < 640px
- Sticky download bar fixed to bottom on mobile
- Hero image hidden on very small screens (< 480px)
- 44px minimum touch targets on all buttons/links
- Body padding-bottom: 72px to prevent content hiding behind sticky bar

### Deployment
- GitHub repo: `https://github.com/jayaswinjay-web/jaypos-website`
- Live: `https://jayaswinjay-web.github.io/jaypos-website/`
- Git: commit and push from `jaypos/website/` directory

## Flutter App

### Location
`jaypos/` — Flutter/Dart POS app for Android (offline-first).

### Architecture
- State management: Riverpod (`flutter_riverpod`)
- Database: Drift (SQLite)
- Backend: Supabase
- Navigation: go_router
- Printing: `print_bluetooth_thermal`, `printing` (PDF)
- Barcode: `mobile_scanner`

### Known Issues (fixed 27 June 2026)

#### 1. Coupon Discount Not Applied
- **Files**: `lib/features/billing/controllers/billing_controller.dart`, `lib/features/billing/screens/billing_screen.dart`, `lib/data/local/database.dart`
- **Root Cause**: Coupon code was validated and stored in state but `discountValue` was never fetched or subtracted from `total`/`grandTotal`.
- **Fix**: In `billing_controller.dart`:
  - Added `couponDiscount` field to `BillingState`
  - In `setCoupon()`, now fetches coupon from DB, calculates discount (flat or percent), stores it in `couponDiscount`
  - `total` getter now: `subtotal + taxAmount - billDiscount - couponDiscount`
  - `checkout()` now sends `coupon_discount` in transaction data
- **In `database.dart`**: `createTransaction()` now reads `coupon_discount` from tx data and passes correct amount to `logCouponRedemption()`

#### 2. Quick Bill SQL Failure
- **Files**: `lib/features/quickbill/screens/quick_bill_screen.dart`
- **Root Cause**: Quick bill creates a transaction item with `product_id: null` but `TransactionItemsTable.productId` has a NOT NULL constraint.
- **Fix**: Use a sentinel value `'QUICK_BILL'` for `product_id` instead of `null`.

#### 3. Dashboard Hardcoded Chart Data
- **Files**: `lib/features/dashboard/screens/dashboard_screen.dart`, `lib/data/local/database.dart`
- **Root Cause**: Weekly sales chart used `5000 + i * 500 + (i%3*300)` — completely fake.
- **Fix**: Added `getDailySalesForWeek()` DB method, created `weekSalesProvider`, wired chart to real data with dynamic `maxY`.

#### 4. Reports Hardcoded Tax Data
- **Files**: `lib/features/reports/screens/reports_screen.dart`, `lib/data/local/database.dart`
- **Root Cause**: Tax tab had hardcoded ₹ values and GSTR buttons did nothing.
- **Fix**: Added `getTaxSummary()` DB method (queries tax by slab from transaction_items), replaced hardcoded values with `taxSummaryProvider`, wired GSTR buttons to export CSV.

### Key File Paths

| Purpose | Path |
|---------|------|
| Billing controller | `lib/features/billing/controllers/billing_controller.dart` |
| Billing screen | `lib/features/billing/screens/billing_screen.dart` |
| Quick bill screen | `lib/features/quickbill/screens/quick_bill_screen.dart` |
| Dashboard screen | `lib/features/dashboard/screens/dashboard_screen.dart` |
| Reports screen | `lib/features/reports/screens/reports_screen.dart` |
| Database (Drift) | `lib/data/local/database.dart` |
| DB tables | `lib/data/local/tables/all_tables.dart` |
| Coupons screen | `lib/features/coupons/screens/coupons_screen.dart` |
| Receipt template | `lib/features/receipts/screens/receipt_template_screen.dart` |
| Providers | `lib/core/di/providers.dart` |
| Router | `lib/core/router/router.dart` |
| Money utils | `lib/core/utils/money.dart` |
