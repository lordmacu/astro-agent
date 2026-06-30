package com.lordmacu.chispa

import com.lordmacu.chispa.wakeword.WakeWordChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WakeWordChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
