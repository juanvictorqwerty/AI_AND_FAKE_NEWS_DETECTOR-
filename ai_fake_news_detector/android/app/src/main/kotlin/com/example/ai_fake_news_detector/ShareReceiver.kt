package com.example.ai_fake_news_detector

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.work.*
import java.io.File
import java.io.FileOutputStream
import java.util.*

/**
 * Minimal activity that receives shared media and delegates processing to background worker.
 * This activity has no UI and finishes immediately after delegating work.
 */
class ShareReceiver : AppCompatActivity() {

    companion object {
        private const val TAG = "ShareReceiver"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle the share intent
        handleShareIntent(intent)

        // Finish immediately - no UI shown
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
        finish()
    }

    private fun handleShareIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                val mimeType = intent.type
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)

                if (uri != null && mimeType != null) {
                    // Handle media files (existing functionality)
                    Log.d(TAG, "Received shared media: $uri, type: $mimeType")

                    // Generate unique task ID
                    val taskId = UUID.randomUUID().toString()

                    // Start background processing
                    enqueueMediaProcessing(uri, mimeType, taskId)

                    // Show initial notification
                    ShareNotificationManager.showProcessingNotification(this, taskId)

                } else if (text != null && text.isNotBlank()) {
                    // Handle text shares (potentially URLs)
                    Log.d(TAG, "Received shared text: $text")
                    handleSharedText(text)

                } else {
                    Log.w(TAG, "Received share intent but missing URI/mime type or text")
                }
            }
            else -> {
                Log.w(TAG, "Received unsupported intent action: ${intent.action}")
            }
        }
    }

    private fun enqueueMediaProcessing(uri: Uri, mimeType: String, taskId: String) {
        // Copy URI content to local file immediately to preserve temporary permissions
        val localFile = copyUriToLocalFile(uri, mimeType, taskId)
        if (localFile == null) {
            Log.e(TAG, "Failed to copy shared media to local file")
            ShareNotificationManager.showErrorNotification(this, taskId, "Failed to access shared media")
            return
        }

        val workRequest = OneTimeWorkRequestBuilder<ShareProcessingWorker>()
            .setInputData(
                workDataOf(
                    ShareProcessingWorker.KEY_FILE_PATH to localFile.absolutePath,
                    ShareProcessingWorker.KEY_MIME_TYPE to mimeType,
                    ShareProcessingWorker.KEY_TASK_ID to taskId
                )
            )
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
            )
            .build()

        WorkManager.getInstance(this).enqueueUniqueWork(
            "share_processing_$taskId",
            ExistingWorkPolicy.REPLACE,
            workRequest
        )

        Log.d(TAG, "Enqueued background processing for task: $taskId")
    }

    private fun handleSharedText(text: String) {
        // Extract URLs from the shared text
        val urlRegex = Regex("""https?://[^\s]+""")
        val urls = urlRegex.findAll(text).map { it.value }.toList()

        if (urls.isNotEmpty()) {
            val url = urls.first() // Take the first URL found
            Log.d(TAG, "Found URL in shared text: $url")

            // Generate unique task ID
            val taskId = UUID.randomUUID().toString()

            // Start background URL processing
            enqueueUrlProcessing(url, taskId)

            // Show initial notification
            ShareNotificationManager.showProcessingNotification(this, taskId)
        } else {
            Log.d(TAG, "No URLs found in shared text")
            // Could show a toast or notification that no URLs were found
        }
    }

    private fun enqueueUrlProcessing(url: String, taskId: String) {
        val workRequest = OneTimeWorkRequestBuilder<UrlProcessingWorker>()
            .setInputData(
                workDataOf(
                    UrlProcessingWorker.KEY_URL to url,
                    UrlProcessingWorker.KEY_TASK_ID to taskId
                )
            )
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
            )
            .build()

        WorkManager.getInstance(this).enqueueUniqueWork(
            "url_processing_$taskId",
            ExistingWorkPolicy.REPLACE,
            workRequest
        )

        Log.d(TAG, "Enqueued background URL processing for task: $taskId")
    }

    private fun copyUriToLocalFile(uri: Uri, mimeType: String, taskId: String): File? {
        return try {
            val contentResolver = contentResolver

            // Create temp file
            val extension = when {
                mimeType.startsWith("image/") -> ".jpg"
                mimeType.startsWith("video/") -> ".mp4"
                else -> ".tmp"
            }

            val tempFile = File(cacheDir, "shared_$taskId$extension")

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(tempFile).use { output ->
                    input.copyTo(output)
                }
            }

            tempFile
        } catch (e: Exception) {
            Log.e(TAG, "Failed to copy URI to local file", e)
            null
        }
    }
}