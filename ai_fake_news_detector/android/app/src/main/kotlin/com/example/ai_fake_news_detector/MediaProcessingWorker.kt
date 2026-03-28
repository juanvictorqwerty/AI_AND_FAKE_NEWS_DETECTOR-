package com.example.ai_fake_news_detector

import android.content.Context
import android.util.Log
import androidx.work.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker for background media processing.
 *
 * Fix 5 – doWork() now calls MediaAnalysisService.sendResultToFlutter /
 *          sendErrorToFlutter so the result actually reaches the Flutter
 *          layer instead of being silently discarded in WorkInfo output data.
 *
 * The WorkInfo output data is kept as well so callers that observe work
 * status via LiveData still get structured output.
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
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.SECONDS)
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

        fun cancelWork(context: Context, taskId: String) {
            WorkManager.getInstance(context)
                .cancelUniqueWork(WORK_NAME_PREFIX + taskId)
            Log.d(TAG, "Work cancelled for task: $taskId")
        }

        fun getWorkStatus(context: Context, taskId: String) {
            WorkManager.getInstance(context)
                .getWorkInfosForUniqueWorkLiveData(WORK_NAME_PREFIX + taskId)
                .observeForever { workInfos ->
                    if (workInfos.isNotEmpty()) {
                        Log.d(TAG, "Work status for task $taskId: ${workInfos[0].state}")
                    }
                }
        }
    }

    private val uploadService = MediaUploadService()

    override suspend fun doWork(): Result {
        val filePath = inputData.getString(KEY_FILE_PATH)
        val fileType = inputData.getString(KEY_FILE_TYPE)
        val taskId   = inputData.getString(KEY_TASK_ID)

        if (filePath == null || fileType == null || taskId == null) {
            Log.e(TAG, "Invalid input data")
            return Result.failure(workDataOf(KEY_RESULT_ERROR to "Invalid input data"))
        }

        Log.d(TAG, "Starting work for task: $taskId")

        return try {
            performAnalysis(filePath, fileType, taskId)
        } catch (e: Exception) {
            Log.e(TAG, "Work failed for task $taskId: ${e.message}")
            if (runAttemptCount < 3) {
                Log.d(TAG, "Retrying work for task: $taskId (attempt ${runAttemptCount + 1})")
                Result.retry()
            } else {
                val errorMsg = e.message ?: "Unknown error"
                // Fix 5 – tell Flutter about the failure.
                MediaAnalysisService.sendErrorToFlutter(taskId, errorMsg)
                Result.failure(
                    workDataOf(
                        KEY_RESULT_STATUS to "failed",
                        KEY_RESULT_ERROR to errorMsg
                    )
                )
            }
        }
    }

    private suspend fun performAnalysis(
        filePath: String,
        fileType: String,
        taskId: String
    ): Result = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Uploading file for task: $taskId")

            // Fix 2 – inform Flutter we are uploading.
            MediaAnalysisService.sendProgressToFlutter(taskId, "uploading", 0.0)

            val uploadResponse = uploadService.uploadFile(filePath, fileType)
            if (!uploadResponse.success) throw Exception(uploadResponse.message)

            Log.d(TAG, "File uploaded: ${uploadResponse.fileId}")

            // Fix 2 – inform Flutter we are now processing.
            MediaAnalysisService.sendProgressToFlutter(taskId, "processing", 0.5)

            val result = uploadService.pollUntilComplete(
                uploadResponse.fileId,
                onStatusUpdate = { analysisResult ->
                    val status = when {
                        analysisResult.isCompleted -> "completed"
                        analysisResult.isFailed    -> "failed"
                        else                       -> "processing"
                    }
                    val progress = if (analysisResult.isCompleted) 1.0 else 0.5
                    // Fix 2 – keep sending progress ticks.
                    MediaAnalysisService.sendProgressToFlutter(taskId, status, progress)
                    Log.d(TAG, "Poll tick for $taskId: $status")
                }
            )

            Log.d(TAG, "Analysis completed for task $taskId: ${result.label}")

            // Fix 5 – send completed result to Flutter, not just WorkInfo.
            MediaAnalysisService.sendResultToFlutter(taskId, result)

            // Also populate WorkInfo output for any LiveData observers.
            Result.success(
                workDataOf(
                    KEY_RESULT_STATUS     to "completed",
                    KEY_RESULT_FILE_ID    to result.fileId,
                    KEY_RESULT_LABEL      to (result.label ?: ""),
                    KEY_RESULT_CONFIDENCE to (result.confidence ?: 0.0)
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Analysis failed for task $taskId: ${e.message}")
            throw e  // Caught in doWork() which handles retry / failure reporting.
        }
    }
}