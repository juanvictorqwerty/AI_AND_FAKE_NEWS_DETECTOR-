package com.example.ai_fake_news_detector

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class SocialMediaProcessingWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "SocialMediaWorker"
        const val KEY_URL = "url"
        const val KEY_TASK_ID = "task_id"
    }

    private val urlProcessor = SocialMediaUrlProcessor(applicationContext)
    private val notificationManager = ShareNotificationManager

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val url = inputData.getString(KEY_URL) ?: return@withContext Result.failure()
        val taskId = inputData.getString(KEY_TASK_ID) ?: return@withContext Result.failure()

        try {
            Log.d(TAG, "Starting social media processing for task: $taskId, URL: $url")

            notificationManager.showProcessingNotification(applicationContext, taskId)

            val platform = urlProcessor.detectPlatform(url)
            if (platform == SocialMediaUrlProcessor.Platform.UNSUPPORTED) {
                Log.w(TAG, "Unsupported platform for URL: $url")
                notificationManager.showErrorNotification(
                    applicationContext,
                    taskId,
                    "Unsupported link"
                )
                return@withContext Result.failure(workDataOf("error" to "Unsupported platform"))
            }

            Log.d(TAG, "Detected platform: $platform")

            val extractedMedia = urlProcessor.extractImageFromUrl(url)
            Log.d(TAG, "Extracted media URL: ${extractedMedia.mediaUrl}, type: ${extractedMedia.mediaType}")

            if (extractedMedia.mediaType == SocialMediaUrlProcessor.MediaType.VIDEO) {
                Log.d(TAG, "Video detected - checking duration constraint")
                notificationManager.showProcessingNotification(applicationContext, taskId, "Processing video (max 10s)...")
            }

            val token = ConfigManager.getAuthToken()
                ?: return@withContext Result.failure(workDataOf("error" to "Authentication required"))

            val tempMediaFile = urlProcessor.downloadMedia(extractedMedia.mediaUrl, taskId, extractedMedia.mediaType)

            val mediaTypeString = if (extractedMedia.mediaType == SocialMediaUrlProcessor.MediaType.VIDEO) "video" else "image"
            val result = urlProcessor.uploadToBackend(tempMediaFile, taskId, token, mediaTypeString)

            notificationManager.showResultNotification(applicationContext, taskId, result)

            urlProcessor.cleanupTempFile(tempMediaFile)

            Log.d(TAG, "Completed social media processing for task: $taskId")
            Result.success()

        } catch (e: UnsupportedOperationException) {
            Log.e(TAG, "Unsupported platform", e)
            notificationManager.showErrorNotification(applicationContext, taskId, "Unsupported link")
            Result.failure(workDataOf("error" to e.message))

        } catch (e: Exception) {
            Log.e(TAG, "Error processing social media URL for task $taskId", e)

            val errorMessage = when {
                e.message?.contains("timed out") == true -> "Request timed out. Please try again."
                e.message?.contains("authentication") == true -> "Authentication failed. Please login again."
                else -> e.message ?: "Unknown error occurred"
            }

            notificationManager.showErrorNotification(applicationContext, taskId, errorMessage)
            Result.failure(workDataOf("error" to e.message))
        }
    }
}
