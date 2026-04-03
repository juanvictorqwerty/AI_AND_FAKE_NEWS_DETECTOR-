package com.example.ai_fake_news_detector

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * WorkManager worker that processes shared URLs in the background.
 * Extracts images from URLs (Instagram, Facebook, etc.) and submits for analysis.
 */
class UrlProcessingWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "UrlProcessingWorker"

        const val KEY_URL = "url"
        const val KEY_TASK_ID = "task_id"
    }

    private val uploadService = MediaUploadService()

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val url = inputData.getString(KEY_URL) ?: return@withContext Result.failure()
        val taskId = inputData.getString(KEY_TASK_ID) ?: return@withContext Result.failure()

        try {
            Log.d(TAG, "Starting URL processing for task: $taskId, URL: $url")

            // Get auth token
            val token = ConfigManager.getAuthToken()
                ?: return@withContext Result.failure(workDataOf("error" to "Authentication required"))

            // Submit URL for analysis
            val response = uploadService.analyzeUrl(url, token)

            // Check response
            val status = response.optString("status", "")
            if (status == "success") {
                Log.d(TAG, "URL analysis started successfully for task: $taskId")

                // For URL analysis, we don't get immediate results since it's async
                // The analysis will complete in the background on the server
                // We could poll for results or just show success message

                // For now, show a generic success message
                val result = AnalysisResult(
                    fileId = "url_$taskId",
                    status = "completed",
                    label = "Analysis started",
                    confidence = 1.0,
                    processingTime = 0.0
                )

                // Update notification with result
                ShareNotificationManager.showResultNotification(applicationContext, taskId, result)

            } else {
                val error = response.optString("message", "Unknown error")
                Log.e(TAG, "URL analysis failed for task $taskId: $error")
                ShareNotificationManager.showErrorNotification(applicationContext, taskId, error)
                return@withContext Result.failure(workDataOf("error" to error))
            }

            Log.d(TAG, "Completed URL processing for task: $taskId")
            Result.success()

        } catch (e: Exception) {
            Log.e(TAG, "Error processing URL for task $taskId", e)

            // Show error notification
            ShareNotificationManager.showErrorNotification(applicationContext, taskId, e.message ?: "Unknown error")

            Result.failure(workDataOf("error" to e.message))
        }
    }
}