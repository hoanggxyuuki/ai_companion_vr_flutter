package com.example.ai_companion_vr_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.util.Log
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i("MainActivity", "🎥 Regular Android Activity starting...")
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register Quest Frame Capture Plugin
        flutterEngine.plugins.add(QuestFrameCapturePlugin())
    }
}
