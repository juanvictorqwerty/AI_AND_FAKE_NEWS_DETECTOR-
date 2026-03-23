package com.example.ai_fake_news_detector

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "android_intent/android_intent"
    private val FACT_CHECK_CHANNEL = "fact_check_channel"
    
    companion object {
        private var flutterEngineInstance: FlutterEngine? = null
        
        fun getFlutterEngine(): FlutterEngine? {
            return flutterEngineInstance
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Store FlutterEngine for use in NotificationForegroundService
        flutterEngineInstance = flutterEngine

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
            
        // Fact Check Channel for notification service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FACT_CHECK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startNotificationService" -> {
                        NotificationForegroundService.startService(this)
                        result.success(true)
                    }
                    "stopNotificationService" -> {
                        NotificationForegroundService.stopService(this)
                        result.success(true)
                    }
                    "updateNotificationResult" -> {
                        val resultText = call.argument<String>("result")
                        println("MainActivity: updateNotificationResult called with: $resultText")
                        if (resultText != null) {
                            // Update notification with result using running service instance
                            val service = NotificationForegroundService.getInstance()
                            if (service != null) {
                                println("MainActivity: Calling service.updateNotificationWithResult")
                                service.updateNotificationWithResult(resultText)
                            } else {
                                println("MainActivity: ERROR - NotificationForegroundService instance is null")
                            }
                        }
                        result.success(true)
                    }
                    "checkBatteryOptimization" -> {
                        val isEnabled = isBatteryOptimizationEnabled()
                        println("MainActivity: Battery optimization enabled: $isEnabled")
                        result.success(isEnabled)
                    }
                    "requestIgnoreBatteryOptimization" -> {
                        println("MainActivity: Requesting to ignore battery optimization")
                        requestIgnoreBatteryOptimizations()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    /**
     * Check if battery optimization is enabled for this app
     */
    private fun isBatteryOptimizationEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            return !powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return false
    }
    
    /**
     * Request to ignore battery optimizations
     */
    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }
}