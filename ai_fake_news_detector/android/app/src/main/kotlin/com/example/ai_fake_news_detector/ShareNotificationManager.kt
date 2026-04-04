package com.example.ai_fake_news_detector

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Notification manager for share processing workflow.
 * Handles processing start, completion, and error notifications.
 */
object ShareNotificationManager {

    private const val CHANNEL_ID = "share_processing_channel"
    private const val CHANNEL_NAME = "Media Analysis"
    private const val CHANNEL_DESCRIPTION = "Notifications for shared media analysis"

    // Notification IDs - use taskId.hashCode() to make them unique
    private const val PROCESSING_NOTIFICATION_BASE_ID = 2000
    private const val RESULT_NOTIFICATION_BASE_ID = 3000

    fun initialize(context: Context) {
        createNotificationChannel(context)
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableVibration(true)
                enableLights(true)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showProcessingNotification(context: Context, taskId: String, message: String = "Your file is being processed") {
        val notificationId = PROCESSING_NOTIFICATION_BASE_ID + taskId.hashCode()

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Analyzing media...")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setProgress(0, 0, true)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    fun showResultNotification(context: Context, taskId: String, result: AnalysisResult) {
        // Cancel processing notification
        val processingId = PROCESSING_NOTIFICATION_BASE_ID + taskId.hashCode()
        NotificationManagerCompat.from(context).cancel(processingId)

        val notificationId = RESULT_NOTIFICATION_BASE_ID + taskId.hashCode()

        val title = "Analysis Complete"
        val text = when {
            result.error != null -> "Analysis failed: ${result.error}"
            result.label != null -> {
                val confidenceText = result.confidence?.let { " (${String.format("%.1f", it * 100)}%)" } ?: ""
                "${result.label}$confidenceText"
            }
            else -> "Analysis completed"
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            // You can add extras here to navigate to results screen
            putExtra("show_last_result", true)
            putExtra("analysis_id", result.fileId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    fun showErrorNotification(context: Context, taskId: String, errorMessage: String) {
        // Cancel processing notification
        val processingId = PROCESSING_NOTIFICATION_BASE_ID + taskId.hashCode()
        NotificationManagerCompat.from(context).cancel(processingId)

        val notificationId = RESULT_NOTIFICATION_BASE_ID + taskId.hashCode()

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Analysis Failed")
            .setContentText("Error: $errorMessage")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    fun cancelProcessingNotification(context: Context, taskId: String) {
        val notificationId = PROCESSING_NOTIFICATION_BASE_ID + taskId.hashCode()
        NotificationManagerCompat.from(context).cancel(notificationId)
    }
}