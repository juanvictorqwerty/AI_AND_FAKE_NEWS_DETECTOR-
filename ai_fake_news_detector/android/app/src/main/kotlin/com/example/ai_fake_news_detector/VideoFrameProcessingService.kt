package com.example.ai_fake_news_detector

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.annotation.GuardedBy
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantLock

/**
 * Foreground service for video frame processing.
 * Extracts frames at exactly 1 FPS and provides progress updates.
 */
class VideoFrameProcessingService : Service() {
    companion object {
        private const val TAG = "VideoFrameProcessingService"
        private const val NOTIFICATION_ID = 1002
        private const val CHANNEL_ID = "video_frame_processing_channel"
        private const val CHANNEL_NAME = "Video Frame Processing"

        const val ACTION_START_PROCESSING = "com.example.ai_fake_news_detector.START_FRAME_PROCESSING"
        const val ACTION_CANCEL_PROCESSING = "com.example.ai_fake_news_detector.CANCEL_FRAME_PROCESSING"
        const val EXTRA_VIDEO_PATH = "video_path"
        const val EXTRA_TASK_ID = "task_id"

        // Shared state for tracking active processing tasks
        private val processingLock = ReentrantLock()
        @GuardedBy("processingLock")
        private val activeTasks = hashMapOf<String, TaskState>()

        data class TaskState(
            val extractor: FrameExtractor? = null,
            var job: Job? = null,
            val isCancelled: AtomicBoolean = AtomicBoolean(false),
            var progress: Double = 0.0,
            val extractedFrames: MutableList<String> = mutableListOf()
        )

        fun startVideoFrameProcessing(
            context: Context,
            videoPath: String,
            taskId: String
        ) {
            val intent = Intent(context, VideoFrameProcessingService::class.java).apply {
                action = ACTION_START_PROCESSING
                putExtra(EXTRA_VIDEO_PATH, videoPath)
                putExtra(EXTRA_TASK_ID, taskId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "Video frame processing service started for task: $taskId")
        }

        fun cancelVideoFrameProcessing(
            context: Context,
            taskId: String
        ) {
            val intent = Intent(context, VideoFrameProcessingService::class.java).apply {
                action = ACTION_CANCEL_PROCESSING
                putExtra(EXTRA_TASK_ID, taskId)
            }
            context.startService(intent)
            Log.d(TAG, "Video frame processing service cancelled for task: $taskId")
        }

        fun getProcessingProgress(taskId: String): Double {
            processingLock.lock()
            try {
                return activeTasks[taskId]?.progress ?: 0.0
            } finally {
                processingLock.unlock()
            }
        }

        fun getExtractedFrames(taskId: String): List<String> {
            processingLock.lock()
            try {
                return activeTasks[taskId]?.extractedFrames?.toList() ?: emptyList()
            } finally {
                processingLock.unlock()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows video frame processing progress"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun createNotification(message: String, progress: Int): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Video Frame Processing")
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

    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var currentTaskId: String? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "VideoFrameProcessingService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_PROCESSING -> {
                val videoPath = intent.getStringExtra(EXTRA_VIDEO_PATH)
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)
                if (videoPath != null && taskId != null) {
                    startFrameProcessing(videoPath, taskId)
                } else {
                    Log.e(TAG, "Invalid intent extras")
                    stopSelf()
                }
            }
            ACTION_CANCEL_PROCESSING -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)
                if (taskId != null) {
                    cancelFrameProcessing(taskId)
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        serviceScope.cancel()
        Log.d(TAG, "VideoFrameProcessingService destroyed")
        super.onDestroy()
    }

    private fun startFrameProcessing(videoPath: String, taskId: String) {
        currentTaskId = taskId

        // Create output directory for frames
        val outputDir = File(
            getExternalCacheDir()?.absolutePath ?: cacheDir.absolutePath,
            "video_frames_$taskId"
        )
        if (!outputDir.exists()) {
            outputDir.mkdirs()
        }

        serviceScope.launch {
            try {
                updateNotification("Initializing frame extraction...", 0)

                // Create FrameExtractor instance
                val extractor = FrameExtractor.create(this@VideoFrameProcessingService, videoPath, outputDir)

                // Register task state
                processingLock.lock()
                try {
                    activeTasks[taskId] = TaskState(
                        extractor = extractor,
                        isCancelled = AtomicBoolean(false)
                    )
                } finally {
                    processingLock.unlock()
                }

                // Start frame extraction in a separate coroutine
                val job = CoroutineScope(Dispatchers.IO).launch {
                    try {
                        extractor.extractFrames(
                            onFrameExtracted = { timestampMs, framePath ->
                                // Update task state with new frame
                                processingLock.lock()
                                try {
                                    activeTasks[taskId]?.extractedFrames?.add(framePath)
                                } finally {
                                    processingLock.unlock()
                                }
                                Log.d(TAG, "Frame extracted at $timestampMs ms: $framePath")
                            },
                            onProgressUpdate = { progress ->
                                // Update task state progress
                                processingLock.lock()
                                try {
                                    activeTasks[taskId]?.progress = progress
                                } finally {
                                    processingLock.unlock()
                                }

                                // Update notification and send progress to Flutter
                                val progressPercent = (progress * 100).toInt()
                                updateNotification(
                                    "Extracting frames... $progressPercent%",
                                    progressPercent
                                )

                                // Send progress to Flutter via MainActivity
                                // NOTE: timestampMs is not in scope here; passing 0 as a safe default.
                                MainActivity.sendVideoFrameProgress(
                                    mapOf(
                                        "taskId" to taskId,
                                        "progress" to progress,
                                        "timestampMs" to 0L
                                    )
                                )
                            },
                            onCompletion = {
                                // Capture frame count and mark as completed while holding the lock
                                val frameCount: Int
                                processingLock.lock()
                                try {
                                    frameCount = activeTasks[taskId]?.extractedFrames?.size ?: 0
                                    activeTasks[taskId]?.isCancelled?.set(true)
                                } finally {
                                    processingLock.unlock()
                                }

                                updateNotification("Frame extraction completed", 100)

                                // Send completion to Flutter
                                MainActivity.sendVideoFrameResult(
                                    mapOf(
                                        "taskId" to taskId,
                                        "status" to "completed",
                                        "frameCount" to frameCount
                                    )
                                )

                                // Stop service after a delay
                                serviceScope.launch {
                                    delay(2000)
                                    stopSelf()
                                }
                            }
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Frame extraction failed: ${e.message}", e)

                        // Update task state with error
                        processingLock.lock()
                        try {
                            activeTasks[taskId]?.isCancelled?.set(true)
                        } finally {
                            processingLock.unlock()
                        }

                        updateNotification("Frame extraction failed: ${e.message}", 0)

                        // Send error to Flutter
                        MainActivity.sendVideoFrameError(
                            mapOf(
                                "taskId" to taskId,
                                "error" to (e.message ?: "Unknown error")
                            )
                        )

                        stopSelf()
                    }
                }

                // Store job reference for cancellation
                processingLock.lock()
                try {
                    activeTasks[taskId]?.job = job
                } finally {
                    processingLock.unlock()
                }

            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize frame extraction: ${e.message}", e)
                updateNotification("Initialization failed: ${e.message}", 0)

                // Send error to Flutter
                MainActivity.sendVideoFrameError(
                    mapOf(
                        "taskId" to taskId,
                        "error" to (e.message ?: "Unknown error")
                    )
                )

                stopSelf()
            }
        }
    }

    private fun cancelFrameProcessing(taskId: String) {
        val state: TaskState?
        processingLock.lock()
        try {
            state = activeTasks.remove(taskId)
        } finally {
            processingLock.unlock()
        }

        state?.let {
            it.isCancelled.set(true)
            it.extractor?.cancel()
            it.job?.cancel()
        }

        updateNotification("Frame extraction cancelled", 0)

        // Send cancellation to Flutter
        MainActivity.sendVideoFrameCancellation(
            mapOf(
                "taskId" to taskId,
                "status" to "cancelled"
            )
        )

        serviceScope.launch {
            delay(1000)
            stopSelf()
        }
    }
}