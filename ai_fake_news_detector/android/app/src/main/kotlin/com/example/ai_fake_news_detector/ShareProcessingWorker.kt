package com.example.ai_fake_news_detector

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

/**
 * WorkManager worker that processes shared media in the background.
 * Handles URI conversion, upload, analysis polling, and notification updates.
 */
class ShareProcessingWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "ShareProcessingWorker"

        const val KEY_URI = "uri"
        const val KEY_MIME_TYPE = "mime_type"
        const val KEY_TASK_ID = "task_id"
    }

    private val uploadService = MediaUploadService()

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val uriString = inputData.getString(KEY_URI) ?: return@withContext Result.failure()
        val mimeType = inputData.getString(KEY_MIME_TYPE) ?: return@withContext Result.failure()
        val taskId = inputData.getString(KEY_TASK_ID) ?: return@withContext Result.failure()

        try {
            Log.d(TAG, "Starting background processing for task: $taskId")

            // Convert URI to file
            val file = convertUriToFile(Uri.parse(uriString), mimeType, taskId)
                ?: return@withContext Result.failure(workDataOf("error" to "Failed to process shared media"))

            // Get auth token
            val token = ConfigManager.getAuthToken()
                ?: return@withContext Result.failure(workDataOf("error" to "Authentication required"))

            // Upload with authentication
            val mediaType = if (mimeType.startsWith("image/")) "image" else "video"
            val uploadResponse = uploadService.uploadMediaWithAuth(file.absolutePath, mediaType, token)

            // Check if response contains synchronous result
            val data = uploadResponse.optJSONObject("data")
            val result = if (data != null) {
                // Synchronous analysis result
                val analysisId = data.optString("analysis_id", "")
                val prediction = data.optString("prediction", "")
                val confidence = data.optDouble("confidence", 0.0).takeIf { !it.isNaN() }
                AnalysisResult(
                    fileId = analysisId,
                    status = "completed",
                    label = prediction,
                    confidence = confidence,
                    processingTime = 0.0
                )
            } else {
                // Fallback: extract file_id and poll (for legacy compatibility)
                val fileId = uploadResponse.optString("file_id", "")
                    ?: return@withContext Result.failure(workDataOf("error" to "Invalid upload response"))
                pollForResult(fileId)
            }

            // Update notification with result
            ShareNotificationManager.showResultNotification(applicationContext, taskId, result)

            Log.d(TAG, "Completed processing for task: $taskId")
            Result.success()

        } catch (e: Exception) {
            Log.e(TAG, "Error processing shared media for task $taskId", e)

            // Show error notification
            ShareNotificationManager.showErrorNotification(applicationContext, taskId, e.message ?: "Unknown error")

            Result.failure(workDataOf("error" to e.message))
        }
    }

    private suspend fun pollForResult(fileId: String): AnalysisResult {
        val maxAttempts = 3// 3 attempts 
        var attempts = 0

        while (attempts < maxAttempts) {
            try {
                val result = uploadService.getAnalysisResult(fileId)
                if (result.isCompleted || result.isFailed) {
                    return result
                }

                // Wait 2 seconds before next poll
                kotlinx.coroutines.delay(2000)
                attempts++
            } catch (e: Exception) {
                Log.e(TAG, "Error polling for result", e)
                throw e
            }
        }

        throw Exception("Analysis timeout after ${maxAttempts * 2} seconds")
    }

    private fun convertUriToFile(uri: Uri, mimeType: String, taskId: String): File? {
        return try {
            val context = applicationContext
            val contentResolver = context.contentResolver

            // Create temp file
            val extension = when {
                mimeType.startsWith("image/") -> ".jpg"
                mimeType.startsWith("video/") -> ".mp4"
                else -> ".tmp"
            }

            val tempFile = File(context.cacheDir, "shared_$taskId$extension")

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(tempFile).use { output ->
                    input.copyTo(output)
                }
            }

            tempFile
        } catch (e: Exception) {
            Log.e(TAG, "Failed to convert URI to file", e)
            null
        }
    }
}