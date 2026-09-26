package com.jaytech.jaypos

import android.app.Activity
import android.app.Notification
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.regex.Pattern

/**
 * UpiNotificationListener — real-time UPI payment detection for JayPOS.
 *
 * Ported from the `upi-pos` reference implementation. It fingerprints UPI
 * payment-success notifications from popular UPI apps, extracts the amount /
 * UTR / our embedded txnRef, and queues the credit into the app's local
 * SQLite `upi_payment_events` table — the same `jaypos.db` file the Flutter
 * (Drift) layer uses. The Dart side polls that queue and matches events
 * against the pending order, flipping it to PAID. No server involved, so this
 * keeps working fully offline.
 *
 * Differences from the reference implementation (deliberate, do not "fix"):
 *  - Amounts are stored as **integer paise**, because every monetary value in
 *    JayPOS is paise (see `core/utils/money.dart`). The reference stored
 *    rupees as REAL; mixing the two would silently break amount matching.
 *  - The DB lives in `app_flutter/jaypos.db` (path_provider's documents dir),
 *    NOT in `getDatabasePath()` — Drift opens it by absolute path.
 *  - Settings are read from JayPOS's own `settings` key/value table.
 *
 * Enabling: Settings -> Notification access -> enable JayPOS.
 */
class UpiNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "UpiListener"

        /** Settings key (JayPOS `settings` table) gating the whole feature. */
        private const val SETTING_DETECTION_ENABLED = "upi_detection_enabled"

        // Known UPI app packages + bank apps to fingerprint
        private val UPI_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user",   // Google Pay
            "com.phonepe.app",                          // PhonePe
            "com.phonepe.app.kotlin",
            "net.one97.paytm",                          // Paytm
            "in.org.npci.upiapp",                       // BHIM
            "in.amazon.mShop.android.shopping",         // Amazon Pay
            "indwin.c3.shareapp",                       // slice
            // Common bank UPI apps
            "com.sbi.upi",
            "com.hdfc.hdfcapp",
            "com.icici.mobile",
            "com.axis.mobile",
            "com.kotak.wallet",
            "com.yesbank",
            "com.pnb.fit",
            "com.mobikwik_new",
            "com.freecharge.android",
            "com.okcredit"
        )

        // Amount patterns: "Rs 123", "₹ 123", "INR 123"
        private val AMOUNT_PATTERN = Pattern.compile(
            "(?:Rs\\.?|INR|₹)\\s?([0-9,]+(?:\\.[0-9]{1,2})?)",
            Pattern.CASE_INSENSITIVE
        )
        private val CREDIT_PATTERN = Pattern.compile(
            "(credited|received|recvd|paid to you|successful|succeeded|money received)",
            Pattern.CASE_INSENSITIVE
        )
        private val DEBIT_PATTERN = Pattern.compile(
            "(debited|sent to|paid to|transfer(red)? out|spent|refund(ed)?|reversed)",
            Pattern.CASE_INSENSITIVE
        )
        private val UTR_PATTERN = Pattern.compile(
            "\\b(UTR|URN|Ref(?:erence)?(?: no)?|A/c ref)[: ]?\\s*([A-Z0-9]{8,16})\\b",
            Pattern.CASE_INSENSITIVE
        )
        // Our embedded txnRef fingerprint, e.g. UPI20260916-000123
        private val TXN_REF_PATTERN = Pattern.compile(
            "(UPI\\d{8}-\\d{6})", Pattern.CASE_INSENSITIVE
        )

        private val executor = Executors.newSingleThreadExecutor()

        /** Absolute path of the Drift DB (path_provider documents dir). */
        fun databasePath(context: Context): String =
            File(File(context.filesDir.parentFile, "app_flutter"), "jaypos.db").absolutePath

        /** Check whether notification access is granted for this app. */
        fun isListenerEnabled(context: Context): Boolean {
            val cn = ComponentName(context, UpiNotificationListener::class.java)
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            return flat != null && flat.contains(cn.flattenToString())
        }

        /** Open the system "Notification access" settings screen. */
        fun openNotificationAccessSettings(activity: Activity) {
            try {
                activity.startActivity(
                    Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                )
            } catch (e: Exception) {
                Log.e(TAG, "Cannot open notification settings: ${e.message}")
            }
        }
    }

    override fun onListenerConnected() {
        Log.i(TAG, "Connected: fingerprinting UPI notifications")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Filter 1 — only supported UPI apps.
        if (sbn.packageName !in UPI_PACKAGES) return
        // Feature must be switched on by the merchant in JayPOS settings.
        if (!detectionEnabled()) return

        val notification: Notification = sbn.notification
        val extras = notification.extras ?: return
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val combined = "${title.orEmpty()} ${text.orEmpty()}"
        if (combined.isBlank()) return

        // Filter 2 — incoming credits only. Debit/refund wording wins over
        // credit wording, so "refund successful" is never treated as income.
        if (DEBIT_PATTERN.matcher(combined).find()) return
        if (!CREDIT_PATTERN.matcher(combined).find()) return

        // Filter 3 — extract amount + references.
        val amountMatch = AMOUNT_PATTERN.matcher(combined)
        if (!amountMatch.find()) return
        val amountRupees = amountMatch.group(1)!!.replace(",", "").toDoubleOrNull() ?: return
        if (amountRupees <= 0) return
        val amountPaise = Math.round(amountRupees * 100.0)

        var reference = ""
        val utr = UTR_PATTERN.matcher(combined)
        if (utr.find()) reference = utr.group(2)!!
        var txnRef = ""
        val txnRefM = TXN_REF_PATTERN.matcher(combined)
        if (txnRefM.find()) txnRef = txnRefM.group(1)!!

        Log.i(TAG, "Detected UPI credit: $amountPaise paise ref=$reference txnRef=$txnRef from ${sbn.packageName}")

        // Filter 4 (matching against the open order) lives on the Dart side —
        // it needs the order/payment model, so it is not duplicated here.
        recordPaymentEventAsync(amountPaise, reference, txnRef, "notification")
    }

    /** Reads the JayPOS settings toggle. Defaults to OFF (opt-in feature). */
    private fun detectionEnabled(): Boolean {
        return try {
            openDb()?.use { db ->
                db.rawQuery(
                    "SELECT value FROM settings WHERE key=? LIMIT 1",
                    arrayOf(SETTING_DETECTION_ENABLED)
                ).use { c ->
                    if (c.moveToFirst()) {
                        val v = c.getString(0)
                        v.equals("true", true) || v == "1"
                    } else {
                        false
                    }
                }
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "detectionEnabled check failed: ${e.message}")
            false
        }
    }

    /** Opens the shared Drift DB, or null if Flutter hasn't created it yet. */
    private fun openDb(): SQLiteDatabase? {
        val path = databasePath(applicationContext)
        if (!File(path).exists()) {
            Log.w(TAG, "DB not created yet at $path")
            return null
        }
        val db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE)
        db.rawQuery("PRAGMA busy_timeout=8000", null).use { }
        return db
    }

    private fun recordPaymentEventAsync(
        amountPaise: Long,
        reference: String,
        txnRef: String,
        source: String
    ) {
        executor.submit {
            try {
                val db = openDb() ?: return@submit
                db.use {
                    // Idempotent: the table is created by the Drift migration,
                    // but the service may fire before the app was ever opened.
                    it.execSQL(
                        """CREATE TABLE IF NOT EXISTS upi_payment_events(
                           id INTEGER PRIMARY KEY AUTOINCREMENT,
                           amount INTEGER NOT NULL,
                           reference TEXT DEFAULT '',
                           txn_ref TEXT DEFAULT '',
                           source TEXT DEFAULT 'notification',
                           created_at TEXT NOT NULL,
                           processed INTEGER NOT NULL DEFAULT 0
                        )"""
                    )
                    val values = ContentValues().apply {
                        put("amount", amountPaise)
                        put("reference", reference)
                        put("txn_ref", txnRef)
                        put("source", source)
                        put(
                            "created_at",
                            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
                        )
                        put("processed", 0)
                    }
                    val id = it.insertOrThrow("upi_payment_events", null, values)
                    Log.i(TAG, "Payment event #$id queued: $amountPaise paise txnRef=$txnRef")
                }
            } catch (e: Exception) {
                Log.e(TAG, "recordPaymentEvent failed: ${e.message}")
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {}
}