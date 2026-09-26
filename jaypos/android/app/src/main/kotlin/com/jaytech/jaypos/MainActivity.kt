package com.jaytech.jaypos

import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.jaytech.jaypos/volume_scanner"
    private val UPI_DETECTION_CHANNEL = "com.jaytech.jaypos/upi_detection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Real-time UPI payment detection: the listener writes straight into
        // the shared SQLite DB, so this channel only handles permission state.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPI_DETECTION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" ->
                    result.success(UpiNotificationListener.isListenerEnabled(this))
                "openNotificationAccessSettings" -> {
                    UpiNotificationListener.openNotificationAccessSettings(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
            channel.invokeMethod("volumeDownPressed", null)
            return true // consume the event
        }
        return super.onKeyDown(keyCode, event)
    }
}
