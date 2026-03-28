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
 * Background service for media analysis.
 *
 * Fix 2  – now sends onAnalysisProgress events to Flutter so the
 *           ProcessingScreen progress bar actually moves.
 * Fix 5  – exposes sendResultToFlutter / sendErrorToFlutter as internal
 *           helpers so MediaProcessingWorker can call them too, closing
 *           the gap where the Worker's result was silently discarded.
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

        fun cancelAnalysis(context: Context, taskId: String) {
            val intent = Intent(context, MediaAnalysisService::class.java).apply {
                action = ACTION_CANCEL_ANALYSIS
                putExtra(EXTRA_TASK_ID, taskId)
            }
            context.startService(intent)
            Log.d(TAG, "Analysis service cancelled for task: $taskId")
        }

        // Fix 5 – shared helpers called by both this Service and the Worker.
        internal fun sendResultToFlutter(taskId: String, result: AnalysisResult) {
            val resultData = mutableMapOf<String, Any>(
                "taskId" to taskId,
                "status" to "completed",
                "fileId" to result.fileId
            )
            result.label?.let { resultData["label"] = it }
            result.confidence?.let { resultData["confidence"] = it }
            result.probabilities?.let { resultData["probabilities"] = it }
            result.processingTime?.let { resultData["processingTime"] = it }
            sendWithRetry(
                taskId = taskId,
                action = { MainActivity.sendAnalysisResult(resultData) },
                logTag = TAG,
                label = "result"
            )
        }

        internal fun sendErrorToFlutter(taskId: String, error: String) {
            val errorData = mapOf(
                "taskId" to taskId,
                "status" to "failed",
                "error" to error
            )
            sendWithRetry(
                taskId = taskId,
                action = { MainActivity.sendAnalysisError(errorData) },
                logTag = TAG,
                label = "error"
            )
        }

        internal fun sendCancellationToFlutter(taskId: String) {
            val data = mapOf("taskId" to taskId, "status" to "cancelled")
            sendWithRetry(
                taskId = taskId,
                action = { MainActivity.sendAnalysisCancellation(data) },
                logTag = TAG,
                label = "cancellation"
            )
        }

        // Fix 2 – progress helper.
        internal fun sendProgressToFlutter(taskId: String, status: String, progress: Double) {
            val data = mapOf(
                "taskId" to taskId,
                "status" to status,
                "progress" to progress
            )
            sendWithRetry(
                taskId = taskId,
                action = { MainActivity.sendAnalysisProgress(data)},
                logTag = TAG,
                label = "progress"
            )
        }

        /** Retry loop extracted to avoid copy-paste in every send* function. */
        private fun sendWithRetry(
            taskId: String,
            action: () -> Boolean,
            logTag: String,
            label: String,
            maxRetries: Int = 5,
            retryDelayMs: Long = 500L
        ) {
            var success = false
            var attempt = 0
            while (!success && attempt < maxRetries) {
                try {
                    success = action()
                } catch (e: Exception) {
                    Log.e(logTag, "Exception sending $label for $taskId: ${e.message}")
                }
                if (!success) {
                    attempt++
                    if (attempt < maxRetries) Thread.sleep(retryDelayMs)
                }
            }
            if (success) {
                Log.d(logTag, "Sent $label for task $taskId")
            } else {
                Log.e(logTag, "Failed to send $label for task $taskId after $maxRetries attempts")
            }
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
                if (taskId != null) cancelAnalysisTask(taskId)
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        serviceScope.cancel()
        Log.d(TAG, "MediaAnalysisService destroyed")
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows media analysis progress"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun startAnalysisForeground(filePath: String, fileType: String, taskId: String) {
        currentTaskId = taskId
        isCancelled = false
        startForeground(NOTIFICATION_ID, createNotification("Starting analysis…", 0))
        Log.d(TAG, "Starting analysis for task: $taskId")
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

    private suspend fun performAnalysis(filePath: String, fileType: String, taskId: String) {
        try {
            // Fix 2 – emit uploading progress before the network call.
            updateNotification("Uploading file…", 0)
            sendProgressToFlutter(taskId, "uploading", 0.0)

            val uploadResponse = uploadService.uploadFile(filePath, fileType)
            if (!uploadResponse.success) throw Exception(uploadResponse.message)

            Log.d(TAG, "File uploaded successfully: ${uploadResponse.fileId}")

            // Fix 2 – emit processing status once upload is done.
            updateNotification("Processing…", 0)
            sendProgressToFlutter(taskId, "processing", 0.5)

            val result = uploadService.pollUntilComplete(
                uploadResponse.fileId,
                onStatusUpdate = { analysisResult ->
                    if (!isCancelled) {
                        val status = when {
                            analysisResult.isCompleted -> "completed"
                            analysisResult.isFailed    -> "failed"
                            else                       -> "processing"
                        }
                        updateNotification(
                            when (status) {
                                "completed" -> "Analysis complete"
                                "failed"    -> "Analysis failed"
                                else        -> "Processing…"
                            }, 0
                        )
                        // Fix 2 – keep Flutter in sync on every poll tick.
                        sendProgressToFlutter(taskId, status, if (status == "completed") 1.0 else 0.5)
                    }
                }
            )

            if (!isCancelled) {
                updateNotification("Analysis complete: ${result.label}", 100)
                Log.d(TAG, "Analysis completed: ${result.label} - ${result.confidence}")
                sendResultToFlutter(taskId, result)  // Fix 5 – uses shared companion helper
                serviceScope.launch {
                    delay(2000)
                    stopSelf()
                }
            }
        } catch (e: Exception) {
            if (!isCancelled) {
                Log.e(TAG, "Analysis failed: ${e.message}")
                updateNotification("Analysis failed: ${e.message}", 0)
                sendErrorToFlutter(taskId, e.message ?: "Unknown error")  // Fix 5
                stopSelf()
            }
        }
    }

    private fun cancelAnalysisTask(taskId: String) {
        if (currentTaskId == taskId) {
            isCancelled = true
            updateNotification("Analysis cancelled", 0)
            Log.d(TAG, "Analysis cancelled for task: $taskId")
            sendCancellationToFlutter(taskId)  // Fix 5
            serviceScope.launch {
                delay(1000)
                stopSelf()
            }
        }
    }

    private fun createNotification(message: String, progress: Int): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
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

    private fun updateNotification(message: String, progress: Int) {
        val notification = createNotification(message, progress)
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "Notification updated: $message")
    }
}