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
    private val MEDIA_ANALYSIS_CHANNEL = "com.example.ai_fake_news_detector/media_analysis"
    
    companion object {
        private var mediaAnalysisChannel: MethodChannel? = null
        
        /**
         * Send analysis result to Flutter
         * @return true if successful, false if channel is null
         */
        fun sendAnalysisResult(resultData: Map<String, Any>): Boolean {
            return if (mediaAnalysisChannel != null) {
                mediaAnalysisChannel?.invokeMethod("onAnalysisResult", resultData)
                true
            } else {
                false
            }
        }
        
        /**
         * Send analysis error to Flutter
         * @return true if successful, false if channel is null
         */
        fun sendAnalysisError(errorData: Map<String, Any>): Boolean {
            return if (mediaAnalysisChannel != null) {
                mediaAnalysisChannel?.invokeMethod("onAnalysisError", errorData)
                true
            } else {
                false
            }
        }
        
        /**
         * Send analysis cancellation to Flutter
         * @return true if successful, false if channel is null
         */
        fun sendAnalysisCancellation(cancellationData: Map<String, Any>): Boolean {
            return if (mediaAnalysisChannel != null) {
                mediaAnalysisChannel?.invokeMethod("onAnalysisCancellation", cancellationData)
                true
            } else {
                false
            }
        }
        
        /**
         * Send analysis progress to Flutter
         * @return true if successful, false if channel is null
         */
        fun sendAnalysisProgress(progressData: Map<String, Any>): Boolean {
            val success = mediaAnalysisChannel != null
            if (success) {
                mediaAnalysisChannel?.invokeMethod("onAnalysisProgress", progressData)
            }
            return success
        }
    }
    
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize ConfigManager
        ConfigManager.init(this)
        
        // Auto-start notification service on first app launch
        // This ensures the service is running even if BootReceiver doesn't trigger
        if (!NotificationForegroundService.isServiceRunning()) {
            println("MainActivity: Auto-starting NotificationForegroundService on first launch")
            NotificationForegroundService.startService(this)
        }
    }
    
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
            
        // Fact Check Channel for notification service
        // Now only used for configuration and service control
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
                    "isNotificationServiceRunning" -> {
                        val isRunning = NotificationForegroundService.isServiceRunning()
                        println("MainActivity: Checking if notification service is running: $isRunning")
                        result.success(isRunning)
                    }
                    "configureBaseUrl" -> {
                        // Configure base URL from Flutter
                        val baseUrl = call.argument<String>("baseUrl")
                        if (baseUrl != null) {
                            ConfigManager.setBaseUrl(baseUrl)
                            println("MainActivity: Base URL configured: $baseUrl")
                        }
                        result.success(true)
                    }
                    "configureAuthToken" -> {
                        // Configure auth token from Flutter
                        val token = call.argument<String>("token")
                        if (token != null) {
                            ConfigManager.setAuthToken(token)
                            println("MainActivity: Auth token configured")
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
            
        // Media Analysis Channel for background processing
        mediaAnalysisChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_ANALYSIS_CHANNEL)
        mediaAnalysisChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAnalysis" -> {
                        val filePath = call.argument<String>("filePath")
                        val fileType = call.argument<String>("fileType")
                        val taskId = call.argument<String>("taskId")
                        
                        if (filePath != null && fileType != null && taskId != null) {
                            try {
                                MediaAnalysisService.startAnalysis(this, filePath, fileType, taskId)
                                result.success(mapOf("status" to "started", "taskId" to taskId))
                            } catch (e: Exception) {
                                result.error("START_FAILED", "Failed to start analysis: ${e.message}", null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Invalid arguments", null)
                        }
                    }
                    "cancelAnalysis" -> {
                        val taskId = call.argument<String>("taskId")
                        if (taskId != null) {
                            try {
                                MediaAnalysisService.cancelAnalysis(this, taskId)
                                result.success(mapOf("status" to "cancelled", "taskId" to taskId))
                            } catch (e: Exception) {
                                result.error("CANCEL_FAILED", "Failed to cancel analysis: ${e.message}", null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Invalid arguments", null)
                        }
                    }
                    "startBackgroundWork" -> {
                        val filePath = call.argument<String>("filePath")
                        val fileType = call.argument<String>("fileType")
                        val taskId = call.argument<String>("taskId")
                        
                        if (filePath != null && fileType != null && taskId != null) {
                            try {
                                MediaProcessingWorker.enqueueWork(this, filePath, fileType, taskId)
                                result.success(mapOf("status" to "enqueued", "taskId" to taskId))
                            } catch (e: Exception) {
                                result.error("ENQUEUE_FAILED", "Failed to enqueue work: ${e.message}", null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Invalid arguments", null)
                        }
                    }
                    "cancelBackgroundWork" -> {
                        val taskId = call.argument<String>("taskId")
                        if (taskId != null) {
                            try {
                                MediaProcessingWorker.cancelWork(this, taskId)
                                result.success(mapOf("status" to "cancelled", "taskId" to taskId))
                            } catch (e: Exception) {
                                result.error("CANCEL_FAILED", "Failed to cancel work: ${e.message}", null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Invalid arguments", null)
                        }
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
