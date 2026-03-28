package com.example.ai_fake_news_detector

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*

/**
 * Background service for media analysis
 *
 * This service handles:
 * - Background file upload
 * - Background polling for results
 * - Progress notifications
 * - Error handling and retry logic
 * - Battery optimization
 */
class MediaAnalysisService : Service() {
    companion object {
        private const val TAG = "MediaAnalysisService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "media_analysis_channel"
        private const val CHANNEL_NAME = "Media Analysis"

        const val ACTION_START_ANALYSIS = "com.example.ai_fake_news_detector.START_ANALYSIS"
        const val ACTION_CANCEL_ANALYSIS = "com.example.ai_fake_news_detector.CANCEL_ANALYSIS"
        const val EXTRA_FILE_PATH = "file_path"
        const val EXTRA_FILE_TYPE = "file_type"
        const val EXTRA_TASK_ID = "task_id"

        /**
         * Start analysis service
         */
        fun startAnalysis(context: Context, filePath: String, fileType: String, taskId: String) {
            val intent = Intent(context, MediaAnalysisService::class.java).apply {
                action = ACTION_START_ANALYSIS
                putExtra(EXTRA_FILE_PATH, filePath)
                putExtra(EXTRA_FILE_TYPE, fileType)
                putExtra(EXTRA_TASK_ID, taskId)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }

            Log.d(TAG, "Analysis service started for task: $taskId")
        }

        /**
         * Cancel analysis service
         */
        fun cancelAnalysis(context: Context, taskId: String) {
            val intent = Intent(context, MediaAnalysisService::class.java).apply {
                action = ACTION_CANCEL_ANALYSIS
                putExtra(EXTRA_TASK_ID, taskId)
            }
            context.startService(intent)
            Log.d(TAG, "Analysis service cancelled for task: $taskId")
        }
    }

    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val uploadService = MediaUploadService()
    private var currentTaskId: String? = null
    private var isCancelled = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "MediaAnalysisService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_ANALYSIS -> {
                val filePath = intent.getStringExtra(EXTRA_FILE_PATH)
                val fileType = intent.getStringExtra(EXTRA_FILE_TYPE)
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)

                if (filePath != null && fileType != null && taskId != null) {
                    startAnalysisForeground(filePath, fileType, taskId)
                } else {
                    Log.e(TAG, "Invalid intent extras")
                    stopSelf()
                }
            }
            ACTION_CANCEL_ANALYSIS -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)
                if (taskId != null) {
                    cancelAnalysis(taskId)
                }
            }
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        serviceScope.cancel()
        Log.d(TAG, "MediaAnalysisService destroyed")
        super.onDestroy()
    }

    /**
     * Create notification channel for Android O and above
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows media analysis progress"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }

    /**
     * Start analysis in foreground with notification
     */
    private fun startAnalysisForeground(filePath: String, fileType: String, taskId: String) {
        currentTaskId = taskId
        isCancelled = false

        // Start foreground service with notification
        val notification = createNotification("Starting analysis...", 0)
        startForeground(NOTIFICATION_ID, notification)

        Log.d(TAG, "Starting analysis for task: $taskId")

        // Start analysis in background
        serviceScope.launch {
            try {
                performAnalysis(filePath, fileType, taskId)
            } catch (e: Exception) {
                Log.e(TAG, "Analysis failed: ${e.message}")
                updateNotification("Analysis failed: ${e.message}", 0)
                stopSelf()
            }
        }
    }

    /**
     * Perform analysis in background
     */
    private suspend fun performAnalysis(filePath: String, fileType: String, taskId: String) {
        try {
            // Update notification
            updateNotification("Uploading file...", 0)

            // Upload file
            val uploadResponse = uploadService.uploadFile(filePath, fileType)

            if (!uploadResponse.success) {
                throw Exception(uploadResponse.message)
            }

            Log.d(TAG, "File uploaded successfully: ${uploadResponse.fileId}")

            // Update notification
            updateNotification("Processing...", 0)

            // Poll until complete
            val result = uploadService.pollUntilComplete(
                uploadResponse.fileId,
                onStatusUpdate = { analysisResult ->
                    if (!isCancelled) {
                        val status = when {
                            analysisResult.isCompleted -> "Analysis complete"
                            analysisResult.isFailed -> "Analysis failed"
                            else -> "Processing..."
                        }
                        updateNotification(status, 0)
                    }
                }
            )

            if (!isCancelled) {
                // Analysis completed successfully
                updateNotification("Analysis complete: ${result.label}", 100)
                Log.d(TAG, "Analysis completed: ${result.label} - ${result.confidence}")

                // Send result to Flutter
                sendResultToFlutter(taskId, result)

                // Stop service after a delay
                serviceScope.launch {
                    delay(2000)
                    stopSelf()
                }
            }
        } catch (e: Exception) {
            if (!isCancelled) {
                Log.e(TAG, "Analysis failed: ${e.message}")
                updateNotification("Analysis failed: ${e.message}", 0)
                sendErrorToFlutter(taskId, e.message ?: "Unknown error")
                stopSelf()
            }
        }
    }

    /**
     * Cancel analysis
     */
    private fun cancelAnalysis(taskId: String) {
        if (currentTaskId == taskId) {
            isCancelled = true
            updateNotification("Analysis cancelled", 0)
            Log.d(TAG, "Analysis cancelled for task: $taskId")

            // Send cancellation to Flutter
            sendCancellationToFlutter(taskId)

            // Stop service
            serviceScope.launch {
                delay(1000)
                stopSelf()
            }
        }
    }

    /**
     * Create notification
     */
    private fun createNotification(message: String, progress: Int): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Media Analysis")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setProgress(100, progress, progress == 0)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }

    /**
     * Update notification
     */
    private fun updateNotification(message: String, progress: Int) {
        val notification = createNotification(message, progress)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "Notification updated: $message")
    }

    /**
     * Send result to Flutter via MethodChannel
     */
    private fun sendResultToFlutter(taskId: String, result: AnalysisResult) {
        try {
            val resultData = mutableMapOf<String, Any>(
                "taskId" to taskId,
                "status" to "completed",
                "fileId" to result.fileId
            )
            result.label?.let { resultData["label"] = it }
            result.confidence?.let { resultData["confidence"] = it }
            result.probabilities?.let { resultData["probabilities"] = it }
            result.processingTime?.let { resultData["processingTime"] = it }

            // This will be called from MainActivity's MethodChannel
            val success = MainActivity.sendAnalysisResult(resultData)
            if (success) {
                Log.d(TAG, "Result sent to Flutter for task: $taskId")
            } else {
                Log.w(TAG, "Failed to send result to Flutter for task: $taskId (channel may be null)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending result to Flutter: ${e.message}")
        }
    }

    /**
     * Send error to Flutter via MethodChannel
     */
    private fun sendErrorToFlutter(taskId: String, error: String) {
        try {
            val errorData = mapOf(
                "taskId" to taskId,
                "status" to "failed",
                "error" to error
            )

            val success = MainActivity.sendAnalysisError(errorData)
            if (success) {
                Log.d(TAG, "Error sent to Flutter for task: $taskId")
            } else {
                Log.w(TAG, "Failed to send error to Flutter for task: $taskId (channel may be null)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending error to Flutter: ${e.message}")
        }
    }

    /**
     * Send cancellation to Flutter via MethodChannel
     */
    private fun sendCancellationToFlutter(taskId: String) {
        try {
            val cancellationData = mapOf(
                "taskId" to taskId,
                "status" to "cancelled"
            )

            val success = MainActivity.sendAnalysisCancellation(cancellationData)
            if (success) {
                Log.d(TAG, "Cancellation sent to Flutter for task: $taskId")
            } else {
                Log.w(TAG, "Failed to send cancellation to Flutter for task: $taskId (channel may be null)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending cancellation to Flutter: ${e.message}")
        }
    }
}
