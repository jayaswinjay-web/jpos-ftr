package com.jaytech.jaypos

import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.jaytech.jaypos/volume_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
