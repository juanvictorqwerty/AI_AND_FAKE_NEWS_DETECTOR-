package com.example.ai_fake_news_detector

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "android_intent/android_intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // Check if overlay permission is granted
                    "canDrawOverlays" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this)
                        } else {
                            true // Always granted below API 23
                        }
                        result.success(granted)
                    }

                    // Opens the exact "Display over other apps" toggle for this app
                    "openOverlaySettings" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } else {
                                // Below API 23, permission is always granted — nothing to open
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Could not open overlay settings: ${e.message}", null)
                        }
                    }

                    // Generic intent launcher (used as fallback)
                    "launch" -> {
                        try {
                            val action = call.argument<String>("action")
                            val data = call.argument<String>("data")
                            val intent = Intent(action).apply {
                                if (data != null) this.data = Uri.parse(data)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Could not launch intent: ${e.message}", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}