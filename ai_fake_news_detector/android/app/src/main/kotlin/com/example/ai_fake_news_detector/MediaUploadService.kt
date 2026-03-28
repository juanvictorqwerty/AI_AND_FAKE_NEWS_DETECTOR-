package com.example.ai_fake_news_detector

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Service for handling media upload and result retrieval from backend
 *
 * This service handles:
 * - File upload via multipart POST request
 * - Polling results endpoint until completion
 * - Retrieving final analysis results
 * - Retry mechanism and timeout handling
 */
class MediaUploadService {
    companion object {
        private const val TAG = "MediaUploadService"
        private const val MAX_RETRY_ATTEMPTS = 3
        private const val UPLOAD_TIMEOUT_MINUTES = 2L
        private const val POLL_TIMEOUT_SECONDS = 30L
        private const val DEFAULT_TIMEOUT_MINUTES = 5L
        private const val DEFAULT_POLL_INTERVAL_SECONDS = 2L
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(UPLOAD_TIMEOUT_MINUTES, TimeUnit.MINUTES)
        .readTimeout(UPLOAD_TIMEOUT_MINUTES, TimeUnit.MINUTES)
        .writeTimeout(UPLOAD_TIMEOUT_MINUTES, TimeUnit.MINUTES)
        .build()

    private var baseUrl: String = "http://192.168.1.152:8000"

    /**
     * Set base URL for API endpoints
     */
    fun setBaseUrl(url: String) {
        baseUrl = url
        Log.d(TAG, "Base URL set to: $baseUrl")
    }

    /**
     * Get MIME type based on file extension
     *
     * @param filePath Path to the file
     * @return Appropriate MIME type string
     */
    private fun getMimeType(filePath: String): String {
        val extension = filePath.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            "mp4" -> "video/mp4"
            "mov" -> "video/quicktime"
            "avi" -> "video/x-msvideo"
            else -> "application/octet-stream"
        }
    }

    /**
     * Upload file to backend via multipart POST request
     *
     * @param filePath Path to the file to upload
     * @param fileType Type of file ('image' or 'video')
     * @return UploadResponse with file_id on success
     * @throws Exception on failure after max retries
     */
    suspend fun uploadFile(filePath: String, fileType: String): UploadResponse {
        var attempts = 0

        while (attempts < MAX_RETRY_ATTEMPTS) {
            try {
                Log.d(TAG, "Uploading file (attempt ${attempts + 1}/$MAX_RETRY_ATTEMPTS)")
                Log.d(TAG, "File path: $filePath")
                Log.d(TAG, "File type: $fileType")

                val file = File(filePath)
                if (!file.exists()) {
                    throw Exception("File not found: $filePath")
                }

                val fileLength = file.length()
                Log.d(TAG, "File size: $fileLength bytes")

                // Create multipart request
                val requestBody = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart(
                        "file",
                        file.name,
                        file.asRequestBody(getMimeType(filePath).toMediaType())
                    )
                    .build()

                val request = Request.Builder()
                    .url("$baseUrl/upload")
                    .post(requestBody)
                    .build()

                Log.d(TAG, "Sending request to $baseUrl/upload")

                // Send request with timeout
                val response = withContext(Dispatchers.IO) {
                    client.newCall(request).execute()
                }

                val responseBody = response.body?.string() ?: ""
                Log.d(TAG, "Response status: ${response.code}")
                Log.d(TAG, "Response body: $responseBody")

                // Check response status
                if (response.isSuccessful) {
                    val jsonResponse = JSONObject(responseBody)
                    val uploadResponse = UploadResponse.fromJson(jsonResponse)

                    if (uploadResponse.success) {
                        Log.d(TAG, "Upload successful, file_id: ${uploadResponse.fileId}")
                        return uploadResponse
                    } else {
                        throw Exception(uploadResponse.message)
                    }
                } else {
                    // Try to parse error message from response
                    var errorMessage = "Upload failed with status ${response.code}"
                    try {
                        val jsonResponse = JSONObject(responseBody)
                        errorMessage = jsonResponse.optString("message", errorMessage)
                    } catch (_: Exception) {}

                    throw Exception(errorMessage)
                }
            } catch (e: java.net.SocketException) {
                attempts++
                Log.e(TAG, "Network error (attempt $attempts): ${e.message}")
                if (attempts >= MAX_RETRY_ATTEMPTS) {
                    throw Exception("Network error after $MAX_RETRY_ATTEMPTS attempts: ${e.message}")
                }
                // Wait before retry
                kotlinx.coroutines.delay((attempts * 2000).toLong())
            } catch (e: java.net.SocketTimeoutException) {
                attempts++
                Log.e(TAG, "Upload timeout (attempt $attempts)")
                if (attempts >= MAX_RETRY_ATTEMPTS) {
                    throw Exception("Upload timeout after $MAX_RETRY_ATTEMPTS attempts")
                }
                // Wait before retry
                kotlinx.coroutines.delay((attempts * 2000).toLong())
            } catch (e: Exception) {
                Log.e(TAG, "Upload error: ${e.message}")
                throw Exception("Upload failed: ${e.message}")
            }
        }

        throw Exception("Upload failed after $MAX_RETRY_ATTEMPTS attempts")
    }

    /**
     * Get analysis result for a file
     *
     * @param fileId ID of the uploaded file
     * @return AnalysisResult with status, label, confidence, and probabilities
     */
    suspend fun getAnalysisResult(fileId: String): AnalysisResult {
        try {
            Log.d(TAG, "Getting analysis result for file_id: $fileId")

            val request = Request.Builder()
                .url("$baseUrl/results/$fileId")
                .get()
                .build()

            val response = withContext(Dispatchers.IO) {
                client.newCall(request).execute()
            }

            val responseBody = response.body?.string() ?: ""
            Log.d(TAG, "Result response: ${response.code}")
            Log.d(TAG, "Result body: $responseBody")

            if (response.isSuccessful) {
                val jsonResponse = JSONObject(responseBody)
                return AnalysisResult.fromJson(jsonResponse)
            } else {
                throw Exception("Failed to get result: ${response.code}")
            }
        } catch (e: java.net.SocketTimeoutException) {
            Log.e(TAG, "Result fetch timeout")
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Result fetch error: ${e.message}")
            throw Exception("Failed to get analysis result: ${e.message}")
        }
    }

    /**
     * Poll results endpoint until completion or timeout
     *
     * @param fileId ID of the uploaded file
     * @param timeout Maximum time to wait for completion (default: 5 minutes)
     * @param interval Polling interval (default: 2 seconds)
     * @param onStatusUpdate Optional callback for status updates
     * @return AnalysisResult when processing is complete
     * @throws Exception on failure or timeout
     */
    suspend fun pollUntilComplete(
        fileId: String,
        timeout: Long = DEFAULT_TIMEOUT_MINUTES,
        interval: Long = DEFAULT_POLL_INTERVAL_SECONDS,
        onStatusUpdate: ((AnalysisResult) -> Unit)? = null
    ): AnalysisResult {
        Log.d(TAG, "Starting polling for file_id: $fileId")
        Log.d(TAG, "Timeout: ${timeout}min, Interval: ${interval}s")

        val startTime = System.currentTimeMillis()
        var pollCount = 0

        while (true) {
            pollCount++
            val elapsed = (System.currentTimeMillis() - startTime) / 1000

            // Check timeout (convert minutes to seconds for comparison)
            if (elapsed > timeout * 60) {
                Log.e(TAG, "Polling timeout after ${elapsed}s")
                throw Exception("Processing timeout after $timeout minutes")
            }

            Log.d(TAG, "Poll #$pollCount (${elapsed}s elapsed)")

            try {
                // Get current result
                val result = getAnalysisResult(fileId)

                Log.d(TAG, "Status: ${result.status}, Label: ${result.label}, Confidence: ${result.confidence}")

                // Call status update callback if provided
                onStatusUpdate?.invoke(result)

                // Check if completed
                if (result.isCompleted) {
                    Log.d(TAG, "Processing completed")
                    return result
                }

                // Check if failed
                if (result.isFailed) {
                    Log.e(TAG, "Processing failed")
                    throw Exception(result.error ?: "Processing failed")
                }

                // Wait before next poll
                kotlinx.coroutines.delay(interval * 1000)
            } catch (e: java.net.SocketTimeoutException) {
                // If it's a timeout error, continue polling
                Log.e(TAG, "Temporary error during poll: ${e.message}")
                kotlinx.coroutines.delay(interval * 1000)
                continue
            } catch (e: java.net.SocketException) {
                // If it's a network error, continue polling
                Log.e(TAG, "Temporary error during poll: ${e.message}")
                kotlinx.coroutines.delay(interval * 1000)
                continue
            } catch (e: Exception) {
                // For other errors, rethrow
                throw e
            }
        }
    }

    /**
     * Complete upload and processing flow
     *
     * @param filePath Path to the file to upload
     * @param fileType Type of file ('image' or 'video')
     * @param onStatusUpdate Optional callback for processing status updates
     * @return AnalysisResult when processing is complete
     */
    suspend fun uploadAndProcess(
        filePath: String,
        fileType: String,
        onStatusUpdate: ((AnalysisResult) -> Unit)? = null
    ): AnalysisResult {
        Log.d(TAG, "Starting upload and process flow")

        // Upload file
        val uploadResponse = uploadFile(filePath, fileType)

        if (!uploadResponse.success) {
            throw Exception(uploadResponse.message)
        }

        // Poll until complete
        return pollUntilComplete(
            uploadResponse.fileId,
            onStatusUpdate = onStatusUpdate
        )
    }
}

/**
 * Data class for upload response
 */
data class UploadResponse(
    val success: Boolean,
    val fileId: String,
    val message: String,
    val fileSize: Long,
    val fileType: String
) {
    companion object {
        fun fromJson(json: JSONObject): UploadResponse {
            return UploadResponse(
                success = json.optBoolean("success", false),
                fileId = json.optString("file_id", ""),
                message = json.optString("message", ""),
                fileSize = json.optLong("file_size", 0),
                fileType = json.optString("file_type", "")
            )
        }
    }
}

/**
 * Data class for analysis result
 */
data class AnalysisResult(
    val fileId: String,
    val status: String,
    val label: String? = null,
    val confidence: Double? = null,
    val probabilities: Map<String, Double>? = null,
    val processingTime: Double? = null,
    val error: String? = null
) {
    val isCompleted: Boolean
        get() = status == "completed"

    val isFailed: Boolean
        get() = status == "failed"

    val isProcessing: Boolean
        get() = status == "processing"

    val confidencePercentage: String
        get() = confidence?.let { String.format("%.2f%%", it * 100) } ?: "N/A"

    companion object {
        fun fromJson(json: JSONObject): AnalysisResult {
            val probabilitiesMap = mutableMapOf<String, Double>()
            json.optJSONObject("probabilities")?.let { probJson ->
                for (key in probJson.keys()) {
                    probabilitiesMap[key] = probJson.getDouble(key)
                }
            }

            return AnalysisResult(
                fileId = json.optString("file_id", ""),
                status = json.optString("status", ""),
                label = json.optString("label", null),
                confidence = json.optDouble("confidence", 0.0).takeIf { !it.isNaN() },
                probabilities = probabilitiesMap.takeIf { it.isNotEmpty() },
                processingTime = json.optDouble("processing_time", 0.0).takeIf { !it.isNaN() },
                error = json.optString("error", null)
            )
        }
    }
}
