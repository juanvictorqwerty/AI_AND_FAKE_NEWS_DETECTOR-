package com.example.ai_fake_news_detector

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Overlay Activity for Quick Settings Tile
 * This activity displays a Flutter overlay popup when triggered from Quick Settings
 */
class OverlayActivity : FlutterActivity() {

    companion object {
        private const val TAG = "OverlayActivity"
        private const val CHANNEL = "com.example.ai_fake_news_detector/overlay"
        private const val REQUEST_OVERLAY_PERMISSION = 1234
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "OverlayActivity created")
        
        // Check and request overlay permission if needed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                requestOverlayPermission()
                return
            }
        }
        
        // Configure window for overlay
        configureOverlayWindow()
        
        // Handle intent data
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "OverlayActivity new intent")
        handleIntent(intent)
    }

    /**
     * Configure the activity as an overlay
     */
    private fun configureOverlayWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
            window.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        } else {
            window.setType(WindowManager.LayoutParams.TYPE_PHONE)
        }
        
        // Set window flags for overlay behavior
        window.setFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
        )
        
        // Set window dimensions (small popup)
        val layoutParams = window.attributes
        layoutParams.width = WindowManager.LayoutParams.MATCH_PARENT
        layoutParams.height = WindowManager.LayoutParams.WRAP_CONTENT
        layoutParams.dimAmount = 0.3f
        window.attributes = layoutParams
    }

    /**
     * Handle incoming intent from Quick Settings Tile
     */
    private fun handleIntent(intent: Intent?) {
        val triggerSource = intent?.getStringExtra("trigger_source")
        val timestamp = intent?.getLongExtra("timestamp", 0L) ?: 0L
        
        Log.d(TAG, "Intent handled - Source: $triggerSource, Timestamp: $timestamp")
        
        // The Flutter side will handle the actual overlay display
        // We just need to ensure the activity is properly configured
    }

    /**
     * Request overlay permission
     */
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_OVERLAY_PERMISSION) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    Log.d(TAG, "Overlay permission granted")
                    configureOverlayWindow()
                    handleIntent(intent)
                } else {
                    Log.w(TAG, "Overlay permission denied")
                    finish()
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up MethodChannel for communication with Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "closeOverlay" -> {
                        Log.d(TAG, "Closing overlay from Flutter")
                        finish()
                        result.success(true)
                    }
                    "getTriggerSource" -> {
                        val source = intent?.getStringExtra("trigger_source") ?: "unknown"
                        result.success(source)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onBackPressed() {
        Log.d(TAG, "Back button pressed - closing overlay")
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "OverlayActivity destroyed")
    }
}
