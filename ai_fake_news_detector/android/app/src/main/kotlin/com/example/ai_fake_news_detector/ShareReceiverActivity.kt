package com.example.ai_fake_news_detector

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

/**
 * Lightweight activity that receives shared media (images/videos) from other apps.
 * 
 * This activity acts as an entry point for shared content and processes it using
 * the existing MediaUploadService infrastructure. It displays results in a minimal
 * overlay UI without launching the full Flutter app.
 * 
 * Features:
 * - Captures shared content via Intent.ACTION_SEND
 * - Converts content:// URIs to temporary files
 * - Calls existing upload and analysis logic
 * - Displays results in lightweight UI
 * - Auto-closes after configurable delay
 */
class ShareReceiverActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "ShareReceiverActivity"
        private const val SUPPORTED_IMAGE_TYPES = "image/"
        private const val SUPPORTED_VIDEO_TYPES = "video/"
    }

    // UI Components
    private lateinit var previewImageView: ImageView
    private lateinit var progressBar: ProgressBar
    private lateinit var statusTextView: TextView
    private lateinit var resultTextView: TextView
    private lateinit var confidenceTextView: TextView
    private lateinit var closeButton: Button
    private lateinit var retryButton: Button
    private lateinit var openAppButton: Button

    // Services
    private val uploadService = MediaUploadService()
    private val mainHandler = Handler(Looper.getMainLooper())

    // State
    private var currentFile: File? = null
    private var isProcessing = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Configure window as system overlay
        window.setFlags(
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
        )

        // Set window type for overlay
        window.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)

        // Set window format to transparent
        window.setFormat(PixelFormat.TRANSLUCENT)

        // Position the overlay at the top of the screen
        val params = window.attributes
        params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        params.y = 50 // Small offset from top
        window.attributes = params

        setContentView(R.layout.activity_share_receiver)

        // Initialize UI components
        initializeViews()

        // Handle the incoming intent
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun initializeViews() {
        previewImageView = findViewById(R.id.previewImageView)
        progressBar = findViewById(R.id.progressBar)
        statusTextView = findViewById(R.id.statusTextView)
        resultTextView = findViewById(R.id.resultTextView)
        confidenceTextView = findViewById(R.id.confidenceTextView)
        closeButton = findViewById(R.id.closeButton)
        retryButton = findViewById(R.id.retryButton)
        openAppButton = findViewById(R.id.openAppButton)

        // Set up button listeners
        closeButton.setOnClickListener { finish() }
        retryButton.setOnClickListener { retryAnalysis() }
        openAppButton.setOnClickListener { openMainApp() }

        // Initially hide result elements
        resultTextView.visibility = View.GONE
        confidenceTextView.visibility = View.GONE
        retryButton.visibility = View.GONE
        openAppButton.visibility = View.GONE
    }

    private fun handleIncomingIntent(intent: Intent) {
        Log.d(TAG, "Handling incoming intent: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_SEND -> {
                handleSendIntent(intent)
            }
            else -> {
                Log.w(TAG, "Unsupported intent action: ${intent.action}")
                showError("Unsupported intent action")
            }
        }
    }

    private fun handleSendIntent(intent: Intent) {
        val type = intent.type
        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)

        Log.d(TAG, "Received share: type=$type, uri=$uri")

        // Validate type
        if (type == null || (!type.startsWith(SUPPORTED_IMAGE_TYPES) && !type.startsWith(SUPPORTED_VIDEO_TYPES))) {
            showError("Unsupported media type: $type")
            return
        }

        // Validate URI
        if (uri == null) {
            showError("No media content received")
            return
        }

        // Determine file type
        val fileType = when {
            type.startsWith(SUPPORTED_IMAGE_TYPES) -> "image"
            type.startsWith(SUPPORTED_VIDEO_TYPES) -> "video"
            else -> {
                showError("Unsupported media type")
                return
            }
        }

        // Show loading state
        showLoading("Processing shared media...")

        // Convert URI to file and process
        lifecycleScope.launch {
            try {
                val file = convertUriToFile(uri, type)
                if (file == null) {
                    showError("Failed to read shared media")
                    return@launch
                }

                currentFile = file
                Log.d(TAG, "Converted URI to file: ${file.absolutePath} (${file.length()} bytes)")

                // Show preview
                showPreview(file, type)

                // Process the media
                processMedia(file, fileType)

            } catch (e: Exception) {
                Log.e(TAG, "Error handling shared content: ${e.message}", e)
                showError("Error processing shared media: ${e.message}")
            }
        }
    }

    /**
     * Convert a content:// URI to a temporary File.
     * Handles temporary permissions granted by the sharing app.
     */
    private suspend fun convertUriToFile(uri: Uri, mimeType: String): File? {
        return withContext(Dispatchers.IO) {
            try {
                // Take persistable URI permission if available
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                } catch (e: SecurityException) {
                    // Not all URIs support persistable permissions, this is OK
                    Log.d(TAG, "Cannot take persistable permission for URI: $uri")
                }

                // Determine file extension from MIME type
                val extension = when {
                    mimeType == "image/jpeg" -> "jpg"
                    mimeType == "image/png" -> "png"
                    mimeType == "image/webp" -> "webp"
                    mimeType == "image/gif" -> "gif"
                    mimeType == "video/mp4" -> "mp4"
                    mimeType == "video/quicktime" -> "mov"
                    mimeType == "video/x-msvideo" -> "avi"
                    mimeType.startsWith("image/") -> mimeType.substringAfter("image/", "jpg")
                    mimeType.startsWith("video/") -> mimeType.substringAfter("video/", "mp4")
                    else -> "tmp"
                }

                // Create temporary file
                val tempFile = File(cacheDir, "shared_media_${System.currentTimeMillis()}.$extension")

                // Copy content from URI to file
                contentResolver.openInputStream(uri)?.use { inputStream ->
                    FileOutputStream(tempFile).use { outputStream ->
                        inputStream.copyTo(outputStream)
                    }
                } ?: return@withContext null

                Log.d(TAG, "Created temp file: ${tempFile.absolutePath} (${tempFile.length()} bytes)")
                tempFile

            } catch (e: Exception) {
                Log.e(TAG, "Error converting URI to file: ${e.message}", e)
                null
            }
        }
    }

    private fun showPreview(file: File, mimeType: String) {
        if (mimeType.startsWith(SUPPORTED_IMAGE_TYPES)) {
            // For images, we could load a thumbnail
            // For simplicity, just show the file name
            statusTextView.text = "Image: ${file.name}"
        } else {
            statusTextView.text = "Video: ${file.name}"
        }
    }

    /**
     * Process media using existing MediaUploadService.
     * This integrates with the existing upload and analysis pipeline.
     */
    private fun processMedia(file: File, fileType: String) {
        if (isProcessing) return
        isProcessing = true

        lifecycleScope.launch {
            try {
                showLoading("Uploading media...")

                // Call existing upload function
                val uploadResponse = uploadService.uploadFile(file.absolutePath, fileType)
                
                if (!uploadResponse.success) {
                    throw Exception(uploadResponse.message)
                }

                Log.d(TAG, "Upload successful: fileId=${uploadResponse.fileId}")
                showLoading("Analyzing media...")

                // Poll for results using existing function
                val result = uploadService.pollUntilComplete(
                    uploadResponse.fileId,
                    onStatusUpdate = { analysisResult ->
                        mainHandler.post {
                            when {
                                analysisResult.isCompleted -> showLoading("Analysis complete!")
                                analysisResult.isFailed -> {} // Will be caught in catch block
                                else -> showLoading("Processing...")
                            }
                        }
                    }
                )

                // Display results
                displayResult(result)

            } catch (e: Exception) {
                Log.e(TAG, "Error processing media: ${e.message}", e)
                showError("Analysis failed: ${e.message}")
            } finally {
                isProcessing = false
            }
        }
    }

    private fun displayResult(result: AnalysisResult) {
        runOnUiThread {
            progressBar.visibility = View.GONE
            
            // Show result
            resultTextView.text = result.label ?: "Unknown"
            resultTextView.visibility = View.VISIBLE

            // Show confidence
            confidenceTextView.text = "Confidence: ${result.confidencePercentage}"
            confidenceTextView.visibility = View.VISIBLE

            // Update status
            statusTextView.text = "Analysis Complete"

            // Show retry and open app buttons
            retryButton.visibility = View.VISIBLE
            openAppButton.visibility = View.VISIBLE

            // Style result based on label
            when (result.label?.lowercase()) {
                "fake" -> {
                    resultTextView.setTextColor(getColor(android.R.color.holo_red_dark))
                    statusTextView.text = "⚠️ Potential Fake Content Detected"
                }
                "real" -> {
                    resultTextView.setTextColor(getColor(android.R.color.holo_green_dark))
                    statusTextView.text = "✓ Content Appears Authentic"
                }
                else -> {
                    resultTextView.setTextColor(getColor(android.R.color.darker_gray))
                }
            }

            // Keep overlay visible until explicitly closed
        }
    }

    private fun showLoading(message: String) {
        runOnUiThread {
            progressBar.visibility = View.VISIBLE
            statusTextView.text = message
            resultTextView.visibility = View.GONE
            confidenceTextView.visibility = View.GONE
            retryButton.visibility = View.GONE
            openAppButton.visibility = View.GONE
        }
    }

    private fun showError(message: String) {
        runOnUiThread {
            if (!::progressBar.isInitialized) return@runOnUiThread
            progressBar.visibility = View.GONE
            statusTextView.text = "Error"
            resultTextView.text = message
            resultTextView.setTextColor(getColor(android.R.color.holo_red_dark))
            resultTextView.visibility = View.VISIBLE
            confidenceTextView.visibility = View.GONE
            retryButton.visibility = View.VISIBLE
            openAppButton.visibility = View.VISIBLE
        }
    }

    private fun retryAnalysis() {
        currentFile?.let { file ->
            val fileType = when {
                file.name.endsWith(".jpg", ignoreCase = true) ||
                file.name.endsWith(".jpeg", ignoreCase = true) ||
                file.name.endsWith(".png", ignoreCase = true) ||
                file.name.endsWith(".webp", ignoreCase = true) ||
                file.name.endsWith(".gif", ignoreCase = true) -> "image"
                
                file.name.endsWith(".mp4", ignoreCase = true) ||
                file.name.endsWith(".mov", ignoreCase = true) ||
                file.name.endsWith(".avi", ignoreCase = true) -> "video"
                
                else -> {
                    showError("Cannot determine file type")
                    return
                }
            }
            
            showLoading("Retrying analysis...")
            processMedia(file, fileType)
        } ?: showError("No file to retry")
    }

    private fun openMainApp() {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                // Pass the file path to the main app
                currentFile?.let { file ->
                    launchIntent.putExtra("shared_file_path", file.absolutePath)
                    launchIntent.putExtra("shared_file_type", when {
                        file.name.endsWith(".jpg", ignoreCase = true) ||
                        file.name.endsWith(".jpeg", ignoreCase = true) ||
                        file.name.endsWith(".png", ignoreCase = true) ||
                        file.name.endsWith(".webp", ignoreCase = true) ||
                        file.name.endsWith(".gif", ignoreCase = true) -> "image"
                        else -> "video"
                    })
                }
                startActivity(launchIntent)
                finish()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error opening main app: ${e.message}", e)
            showError("Could not open main app")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up temporary file
        currentFile?.let { file ->
            try {
                if (file.exists()) {
                    file.delete()
                    Log.d(TAG, "Cleaned up temp file: ${file.absolutePath}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning up temp file: ${e.message}")
            }
        }
    }
}
