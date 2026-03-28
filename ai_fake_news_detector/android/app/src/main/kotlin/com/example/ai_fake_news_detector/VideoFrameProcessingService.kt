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
 * Extracts frames at exactly 1 FPS, uploads them to the backend, and
 * reports progress / results back to Flutter via [MainActivity].
 *
 * All shared data classes (FrameResult, LabelStats, VideoUploadResponse, etc.)
 * live in MediaUploadService.kt — do NOT redeclare them here.
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
        const val EXTRA_BASE_URL = "base_url"

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
            taskId: String,
            baseUrl: String? = null
        ) {
            val intent = Intent(context, VideoFrameProcessingService::class.java).apply {
                action = ACTION_START_PROCESSING
                putExtra(EXTRA_VIDEO_PATH, videoPath)
                putExtra(EXTRA_TASK_ID, taskId)
                baseUrl?.let { putExtra(EXTRA_BASE_URL, it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "Frame processing service started for task: $taskId")
        }

        fun cancelVideoFrameProcessing(context: Context, taskId: String) {
            val intent = Intent(context, VideoFrameProcessingService::class.java).apply {
                action = ACTION_CANCEL_PROCESSING
                putExtra(EXTRA_TASK_ID, taskId)
            }
            context.startService(intent)
            Log.d(TAG, "Frame processing service cancelled for task: $taskId")
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

    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val uploadService = MediaUploadService()
    private var currentTaskId: String? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "VideoFrameProcessingService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // FIX: Must call startForeground() within 5 seconds of onStartCommand on API 26+,
        // before doing any real work. Doing it here unconditionally is the safest approach.
        startForeground(NOTIFICATION_ID, createNotification("Starting video processing…", 0))

        when (intent?.action) {
            ACTION_START_PROCESSING -> {
                val videoPath = intent.getStringExtra(EXTRA_VIDEO_PATH)
                val taskId    = intent.getStringExtra(EXTRA_TASK_ID)
                val baseUrl   = intent.getStringExtra(EXTRA_BASE_URL)
                if (videoPath != null && taskId != null) {
                    startFrameProcessing(videoPath, taskId, baseUrl)
                } else {
                    Log.e(TAG, "Invalid intent extras for ACTION_START_PROCESSING")
                    stopSelf()
                }
            }
            ACTION_CANCEL_PROCESSING -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)
                if (taskId != null) cancelFrameProcessing(taskId)
            }
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        serviceScope.cancel()
        Log.d(TAG, "VideoFrameProcessingService destroyed")
        super.onDestroy()
    }

    // -----------------------------------------------------------------------
    // Notification helpers
    // -----------------------------------------------------------------------

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
        val launchIntent  = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
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

    // -----------------------------------------------------------------------
    // Frame processing
    // -----------------------------------------------------------------------

    private fun startFrameProcessing(videoPath: String, taskId: String, baseUrl: String?) {
        currentTaskId = taskId

        // Set the base URL for the upload service if provided
        baseUrl?.let { uploadService.baseUrl = it }
        Log.d(TAG, "Upload base URL: ${uploadService.baseUrl}")

        val outputDir = File(
            getExternalCacheDir()?.absolutePath ?: cacheDir.absolutePath,
            "video_frames_$taskId"
        ).also { if (!it.exists()) it.mkdirs() }

        serviceScope.launch {
            try {
                updateNotification("Initializing frame extraction...", 0)

                val extractor = FrameExtractor.create(
                    this@VideoFrameProcessingService, videoPath, outputDir
                )

                processingLock.lock()
                try {
                    activeTasks[taskId] = TaskState(
                        extractor   = extractor,
                        isCancelled = AtomicBoolean(false)
                    )
                } finally {
                    processingLock.unlock()
                }

                val job = CoroutineScope(Dispatchers.IO).launch {
                    try {
                        extractor.extractFrames(
                            onFrameExtracted = { timestampMs, framePath ->
                                processingLock.lock()
                                try {
                                    activeTasks[taskId]?.extractedFrames?.add(framePath)
                                } finally {
                                    processingLock.unlock()
                                }
                                Log.d(TAG, "Frame extracted at ${timestampMs}ms: $framePath")
                            },
                            onProgressUpdate = { progress ->
                                processingLock.lock()
                                try {
                                    activeTasks[taskId]?.progress = progress
                                } finally {
                                    processingLock.unlock()
                                }

                                val progressPercent = (progress * 100).toInt()
                                updateNotification("Extracting frames... $progressPercent%", progressPercent)

                                MainActivity.sendVideoFrameProgress(
                                    mapOf(
                                        "taskId"      to taskId,
                                        "progress"    to progress,
                                        "timestampMs" to 0L
                                    )
                                )
                            },
                            onCompletion = {
                                val frameCount: Int
                                val framePaths: List<String>
                                processingLock.lock()
                                try {
                                    frameCount = activeTasks[taskId]?.extractedFrames?.size ?: 0
                                    framePaths = activeTasks[taskId]?.extractedFrames?.toList() ?: emptyList()
                                    activeTasks[taskId]?.isCancelled?.set(true)
                                } finally {
                                    processingLock.unlock()
                                }

                                if (frameCount > 60) {
                                    Log.e(TAG, "Frame count ($frameCount) exceeds maximum (60)")
                                    framePaths.forEach { runCatching { File(it).delete() } }
                                    runCatching { outputDir.deleteRecursively() }
                                    updateNotification("Too many frames extracted", 0)
                                    MainActivity.sendVideoFrameError(
                                        mapOf(
                                            "taskId" to taskId,
                                            "error"  to "Video too long: extracted $frameCount frames (max 60). Please use a shorter video."
                                        )
                                    )
                                    stopSelf()
                                    return@extractFrames
                                }

                                updateNotification("Frame extraction completed, uploading...", 100)

                                serviceScope.launch {
                                    try {
                                        MainActivity.sendVideoFrameProgress(
                                            mapOf(
                                                "taskId"     to taskId,
                                                "status"     to "uploading_frames",
                                                "progress"   to 0.0,
                                                "frameCount" to frameCount
                                            )
                                        )

                                        val uploadResponse = uploadService.uploadFramesToVideoEndpoint(framePaths)

                                        MainActivity.sendVideoFrameProgress(
                                            mapOf(
                                                "taskId"   to taskId,
                                                "status"   to "processing",
                                                "progress" to 0.5
                                            )
                                        )

                                        framePaths.forEach { framePath ->
                                            try {
                                                File(framePath).delete()
                                                Log.d(TAG, "Deleted frame: $framePath")
                                            } catch (e: Exception) {
                                                Log.w(TAG, "Failed to delete frame: $framePath", e)
                                            }
                                        }
                                        runCatching { outputDir.deleteRecursively() }

                                        MainActivity.sendVideoFrameResult(
                                            mapOf(
                                                "taskId"              to taskId,
                                                "status"              to "completed",
                                                "prediction"          to uploadResponse.prediction,
                                                "confidence"          to uploadResponse.confidence,
                                                "frameCount"          to uploadResponse.frameCount,
                                                "validFrameCount"     to uploadResponse.validFrameCount,
                                                "aggregatedScore"     to uploadResponse.aggregatedScore,
                                                "frames"              to uploadResponse.frames.map { frame ->
                                                    mapOf(
                                                        "filename"   to frame.filename,
                                                        "prediction" to frame.prediction,
                                                        "confidence" to frame.confidence,
                                                        "url"        to (frame.url ?: "")
                                                    )
                                                },
                                                "labelDistribution"   to uploadResponse.labelDistribution.mapValues { (_, stats) ->
                                                    mapOf(
                                                        "count"           to stats.count,
                                                        "totalConfidence" to stats.totalConfidence,
                                                        "avgConfidence"   to stats.avgConfidence
                                                    )
                                                },
                                                "totalProcessingTime" to uploadResponse.totalProcessingTime
                                            )
                                        )

                                        updateNotification("Video analysis completed", 100)

                                        serviceScope.launch {
                                            delay(2000)
                                            stopSelf()
                                        }
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Frame upload failed: ${e.message}", e)
                                        framePaths.forEach { runCatching { File(it).delete() } }

                                        val errorMessage = when {
                                            e.message?.contains("timeout", ignoreCase = true) == true ->
                                                "Upload timed out. Please check your internet connection and try again."
                                            e.message?.contains("network", ignoreCase = true) == true ||
                                            e.message?.contains("SocketException", ignoreCase = true) == true ->
                                                "Network error. Please check your internet connection and try again."
                                            e.message?.contains("failed to connect", ignoreCase = true) == true ||
                                            e.message?.contains("UnknownHostException", ignoreCase = true) == true ->
                                                "Cannot connect to server. Please check your internet connection and try again."
                                            else -> "Upload failed: ${e.message ?: "Unknown error"}"
                                        }

                                        updateNotification("Frame upload failed", 0)
                                        MainActivity.sendVideoFrameError(
                                            mapOf("taskId" to taskId, "error" to errorMessage)
                                        )
                                        stopSelf()
                                    }
                                }
                            }
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Frame extraction failed: ${e.message}", e)

                        processingLock.lock()
                        try {
                            activeTasks[taskId]?.isCancelled?.set(true)
                        } finally {
                            processingLock.unlock()
                        }

                        updateNotification("Frame extraction failed: ${e.message}", 0)
                        MainActivity.sendVideoFrameError(
                            mapOf("taskId" to taskId, "error" to (e.message ?: "Unknown error"))
                        )
                        stopSelf()
                    }
                }

                processingLock.lock()
                try {
                    activeTasks[taskId]?.job = job
                } finally {
                    processingLock.unlock()
                }

            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize frame extraction: ${e.message}", e)
                updateNotification("Initialization failed: ${e.message}", 0)
                MainActivity.sendVideoFrameError(
                    mapOf("taskId" to taskId, "error" to (e.message ?: "Unknown error"))
                )
                stopSelf()
            }
        }
    }

    // -----------------------------------------------------------------------
    // Cancellation
    // -----------------------------------------------------------------------

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

            it.extractedFrames.forEach { framePath ->
                try {
                    File(framePath).delete()
                    Log.d(TAG, "Deleted frame on cancel: $framePath")
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to delete frame on cancel: $framePath", e)
                }
            }
        }

        val outputDir = File(
            getExternalCacheDir()?.absolutePath ?: cacheDir.absolutePath,
            "video_frames_$taskId"
        )
        try {
            outputDir.deleteRecursively()
            Log.d(TAG, "Deleted frame directory on cancel: ${outputDir.absolutePath}")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to delete frame directory on cancel", e)
        }

        updateNotification("Frame extraction cancelled", 0)
        MainActivity.sendVideoFrameCancellation(
            mapOf("taskId" to taskId, "status" to "cancelled")
        )

        serviceScope.launch {
            delay(1000)
            stopSelf()
        }
    }
}
