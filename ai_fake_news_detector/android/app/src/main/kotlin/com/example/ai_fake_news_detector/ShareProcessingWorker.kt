package com.example.ai_fake_news_detector

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.example.ai_fake_news_detector.FrameExtractor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File

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

        const val KEY_FILE_PATH = "file_path"
        const val KEY_MIME_TYPE = "mime_type"
        const val KEY_TASK_ID = "task_id"
    }

    private val uploadService = MediaUploadService()

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val filePath = inputData.getString(KEY_FILE_PATH) ?: return@withContext Result.failure()
        val mimeType = inputData.getString(KEY_MIME_TYPE) ?: return@withContext Result.failure()
        val taskId = inputData.getString(KEY_TASK_ID) ?: return@withContext Result.failure()

        try {
            Log.d(TAG, "Starting background processing for task: $taskId")

            val file = File(filePath)
            if (!file.exists()) {
                return@withContext Result.failure(workDataOf("error" to "Shared media file not found"))
            }

            // Get auth token
            val token = ConfigManager.getAuthToken()
                ?: return@withContext Result.failure(workDataOf("error" to "Authentication required"))

            val result = if (mimeType.startsWith("image/")) {
                // For images, upload directly
                val uploadResponse = uploadService.uploadMediaWithAuth(file.absolutePath, "image", token)

                // Check if response contains synchronous result
                val data = uploadResponse.optJSONObject("data")
                if (data != null) {
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
            } else {
                // For videos, extract frames from first 15 seconds and upload to aggregation endpoint
                val outputDir = File(applicationContext.cacheDir, "share_frames_$taskId").also { if (!it.exists()) it.mkdirs() }
                val extractor = FrameExtractor.create(applicationContext, file.absolutePath, outputDir, 15)

                val framePaths = mutableListOf<String>()
                extractor.extractFrames(
                    onFrameExtracted = { _, framePath -> framePaths.add(framePath) },
                    onProgressUpdate = { },
                    onCompletion = { }
                )

                if (framePaths.isEmpty()) {
                    return@withContext Result.failure(workDataOf("error" to "Failed to extract frames from video"))
                }

                // Upload frames to aggregation endpoint
                val videoResponse = uploadService.uploadFramesToVideoEndpoint(framePaths)

                // Clean up extracted frames
                framePaths.forEach { runCatching { File(it).delete() } }
                runCatching { outputDir.deleteRecursively() }

                // Convert to AnalysisResult
                AnalysisResult(
                    fileId = videoResponse.analysisId ?: taskId,
                    status = "completed",
                    label = videoResponse.prediction,
                    confidence = videoResponse.confidence,
                    processingTime = videoResponse.totalProcessingTime
                )
            }

            // Update notification with result
            ShareNotificationManager.showResultNotification(applicationContext, taskId, result)

            // Clean up the temporary file
            runCatching { file.delete() }

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


}