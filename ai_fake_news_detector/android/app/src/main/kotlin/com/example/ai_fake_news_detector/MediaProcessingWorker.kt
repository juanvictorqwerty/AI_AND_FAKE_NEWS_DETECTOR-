package com.example.ai_fake_news_detector

import android.content.Context
import android.util.Log
import androidx.work.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker for background media processing
 *
 * This worker handles:
 * - Long-running background tasks
 * - Battery-efficient processing
 * - Survives app termination
 * - Automatic retry on failure
 */
class MediaProcessingWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    companion object {
        private const val TAG = "MediaProcessingWorker"
        private const val WORK_NAME_PREFIX = "media_analysis_"

        const val KEY_FILE_PATH = "file_path"
        const val KEY_FILE_TYPE = "file_type"
        const val KEY_TASK_ID = "task_id"
        const val KEY_RESULT_STATUS = "result_status"
        const val KEY_RESULT_FILE_ID = "result_file_id"
        const val KEY_RESULT_LABEL = "result_label"
        const val KEY_RESULT_CONFIDENCE = "result_confidence"
        const val KEY_RESULT_ERROR = "result_error"

        /**
         * Enqueue media analysis work
         */
        fun enqueueWork(context: Context, filePath: String, fileType: String, taskId: String) {
            val workRequest = OneTimeWorkRequestBuilder<MediaProcessingWorker>()
                .setInputData(
                    workDataOf(
                        KEY_FILE_PATH to filePath,
                        KEY_FILE_TYPE to fileType,
                        KEY_TASK_ID to taskId
                    )
                )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    1,
                    TimeUnit.SECONDS
                )
                .addTag(WORK_NAME_PREFIX + taskId)
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    WORK_NAME_PREFIX + taskId,
                    ExistingWorkPolicy.REPLACE,
                    workRequest
                )

            Log.d(TAG, "Work enqueued for task: $taskId")
        }

        /**
         * Cancel media analysis work
         */
        fun cancelWork(context: Context, taskId: String) {
            WorkManager.getInstance(context)
                .cancelUniqueWork(WORK_NAME_PREFIX + taskId)
            Log.d(TAG, "Work cancelled for task: $taskId")
        }

        /**
         * Get work status
         */
        fun getWorkStatus(context: Context, taskId: String) {
            WorkManager.getInstance(context)
                .getWorkInfosForUniqueWorkLiveData(WORK_NAME_PREFIX + taskId)
                .observeForever { workInfos ->
                    if (workInfos.isNotEmpty()) {
                        val workInfo = workInfos[0]
                        Log.d(TAG, "Work status for task $taskId: ${workInfo.state}")
                    }
                }
        }
    }

    private val uploadService = MediaUploadService()

    override suspend fun doWork(): Result {
        val filePath = inputData.getString(KEY_FILE_PATH)
        val fileType = inputData.getString(KEY_FILE_TYPE)
        val taskId = inputData.getString(KEY_TASK_ID)

        if (filePath == null || fileType == null || taskId == null) {
            Log.e(TAG, "Invalid input data")
            return Result.failure(
                workDataOf(KEY_RESULT_ERROR to "Invalid input data")
            )
        }

        Log.d(TAG, "Starting work for task: $taskId")

        return try {
            performAnalysis(filePath, fileType, taskId)
        } catch (e: Exception) {
            Log.e(TAG, "Work failed for task $taskId: ${e.message}")

            // Check if we should retry
            if (runAttemptCount < 3) {
                Log.d(TAG, "Retrying work for task: $taskId (attempt ${runAttemptCount + 1})")
                Result.retry()
            } else {
                Result.failure(
                    workDataOf(
                        KEY_RESULT_STATUS to "failed",
                        KEY_RESULT_ERROR to (e.message ?: "Unknown error")
                    )
                )
            }
        }
    }

    /**
     * Perform analysis in background
     */
    private suspend fun performAnalysis(filePath: String, fileType: String, taskId: String): Result {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Uploading file for task: $taskId")

                // Upload file
                val uploadResponse = uploadService.uploadFile(filePath, fileType)

                if (!uploadResponse.success) {
                    throw Exception(uploadResponse.message)
                }

                Log.d(TAG, "File uploaded successfully: ${uploadResponse.fileId}")

                // Poll until complete
                val result = uploadService.pollUntilComplete(
                    uploadResponse.fileId,
                    onStatusUpdate = { analysisResult ->
                        // Update progress notification
                        val progress = when {
                            analysisResult.isCompleted -> 100
                            analysisResult.isFailed -> 0
                            else -> 50
                        }
                        Log.d(TAG, "Analysis progress for task $taskId: ${analysisResult.status}")
                    }
                )

                Log.d(TAG, "Analysis completed for task $taskId: ${result.label}")

                // Return success with result data (handle nullable values)
                Result.success(
                    workDataOf(
                        KEY_RESULT_STATUS to "completed",
                        KEY_RESULT_FILE_ID to result.fileId,
                        KEY_RESULT_LABEL to (result.label ?: ""),
                        KEY_RESULT_CONFIDENCE to (result.confidence ?: 0.0)
                    )
                )
            } catch (e: Exception) {
                Log.e(TAG, "Analysis failed for task $taskId: ${e.message}")
                throw e
            }
        }
    }
}
