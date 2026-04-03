package com.example.ai_fake_news_detector

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

// ---------------------------------------------------------------------------
// Data classes — defined once here; referenced from VideoFrameProcessingService
// ---------------------------------------------------------------------------

/**
 * Response from the generic /upload endpoint.
 */
data class UploadResponse(
    val success: Boolean,
    val fileId: String,
    val message: String,
    val fileSize: Long,
    val fileType: String
) {
    companion object {
        fun fromJson(json: JSONObject) = UploadResponse(
            success  = json.optBoolean("success", false),
            fileId   = json.optString("file_id", ""),
            message  = json.optString("message", ""),
            fileSize = json.optLong("file_size", 0),
            fileType = json.optString("file_type", "")
        )
    }
}

/**
 * Polling result from the /results/{fileId} endpoint.
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
    val isCompleted: Boolean get() = status == "completed"
    val isFailed:    Boolean get() = status == "failed"
    val isProcessing: Boolean get() = status == "processing"

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
                fileId         = json.optString("file_id", ""),
                status         = json.optString("status", ""),
                label          = json.optString("label", null),
                confidence     = json.optDouble("confidence", 0.0).takeIf { !it.isNaN() },
                probabilities  = probabilitiesMap.takeIf { it.isNotEmpty() },
                processingTime = json.optDouble("processing_time", 0.0).takeIf { !it.isNaN() },
                error          = if (json.isNull("error")) null else json.optString("error", null)
            )
        }
    }
}

/**
 * Individual frame result from the /upload/video endpoint.
 */
data class FrameResult(
    val filename: String,
    val prediction: String,
    val confidence: Double,
    val url: String? = null
) {
    companion object {
        fun fromJson(json: JSONObject) = FrameResult(
            filename   = json.optString("filename", ""),
            prediction = json.optString("prediction", ""),
            confidence = json.optDouble("confidence", 0.0),
            url        = json.optString("url", null)
        )
    }
}

/**
 * Per-label statistics from the /upload/video endpoint.
 */
data class LabelStats(
    val count: Int,
    val totalConfidence: Double,
    val avgConfidence: Double
) {
    companion object {
        fun fromJson(json: JSONObject) = LabelStats(
            count           = json.optInt("count", 0),
            totalConfidence = json.optDouble("total_confidence", 0.0),
            avgConfidence   = json.optDouble("avg_confidence", 0.0)
        )
    }
}

/**
 * Aggregated response from the /upload/video endpoint.
 */
data class VideoUploadResponse(
    val status: String,
    val prediction: String,
    val confidence: Double,
    val frameCount: Int,
    val validFrameCount: Int,
    val aggregatedScore: Double,
    val frames: List<FrameResult>,
    val labelDistribution: Map<String, LabelStats>,
    val totalProcessingTime: Double,
    val analysisId: String? = null,
    val error: String? = null
) {
    companion object {
        fun fromJson(json: JSONObject): VideoUploadResponse {
            val framesList = mutableListOf<FrameResult>()
            json.optJSONArray("frames")?.let { arr ->
                for (i in 0 until arr.length()) {
                    framesList.add(FrameResult.fromJson(arr.getJSONObject(i)))
                }
            }

            val labelDistMap = mutableMapOf<String, LabelStats>()
            json.optJSONObject("label_distribution")?.let { distJson ->
                for (key in distJson.keys()) {
                    labelDistMap[key] = LabelStats.fromJson(distJson.getJSONObject(key))
                }
            }

            return VideoUploadResponse(
                status              = json.optString("status", ""),
                prediction          = json.optString("prediction", ""),
                confidence          = json.optDouble("confidence", 0.0),
                frameCount          = json.optInt("frame_count", 0),
                validFrameCount     = json.optInt("valid_frame_count", 0),
                aggregatedScore     = json.optDouble("aggregated_score", 0.0),
                frames              = framesList,
                labelDistribution   = labelDistMap,
                totalProcessingTime = json.optDouble("total_processing_time", 0.0),
                analysisId          = json.optString("analysis_id", null),
                error               = if (json.isNull("error")) null else json.optString("error", null)
            )
        }
    }
}

// ---------------------------------------------------------------------------
// MediaUploadService
// ---------------------------------------------------------------------------

/**
 * Handles media upload and result retrieval from the backend.
 *
 * Responsibilities:
 * - File upload via multipart POST
 * - Polling the results endpoint until completion
 * - Retry mechanism and timeout handling
 * - Multi-frame upload to /upload/video
 * - JWT authenticated upload to /analyze/media
 */
class MediaUploadService {
    companion object {
        private const val TAG = "MediaUploadService"
        private const val MAX_RETRY_ATTEMPTS = 3
        private const val UPLOAD_TIMEOUT_MINUTES = 2L
        private const val DEFAULT_TIMEOUT_MINUTES = 5L
        private const val DEFAULT_POLL_INTERVAL_SECONDS = 2L
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(UPLOAD_TIMEOUT_MINUTES, TimeUnit.MINUTES)
        .readTimeout(UPLOAD_TIMEOUT_MINUTES, TimeUnit.MINUTES)
        .writeTimeout(UPLOAD_TIMEOUT_MINUTES, TimeUnit.MINUTES)
        .build()

    var baseUrl: String = ConfigManager.getMediaUploadUrl()

    /** Derive MIME type from file extension. */
    private fun getMimeType(filePath: String): String {
        return when (filePath.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png"         -> "image/png"
            "webp"        -> "image/webp"
            "gif"         -> "image/gif"
            "mp4"         -> "video/mp4"
            "mov"         -> "video/quicktime"
            "avi"         -> "video/x-msvideo"
            else          -> "application/octet-stream"
        }
    }

    /**
     * Upload a single file to the /upload endpoint.
     *
     * @param filePath Path to the file
     * @param fileType "image" or "video"
     * @return [UploadResponse] containing the assigned file_id
     * @throws Exception after [MAX_RETRY_ATTEMPTS] failures
     */
    suspend fun uploadFile(filePath: String, fileType: String): UploadResponse {
        var attempts = 0

        while (attempts < MAX_RETRY_ATTEMPTS) {
            try {
                Log.d(TAG, "Uploading file (attempt ${attempts + 1}/$MAX_RETRY_ATTEMPTS): $filePath")

                val file = File(filePath)
                if (!file.exists()) throw Exception("File not found: $filePath")
                Log.d(TAG, "File size: ${file.length()} bytes")

                val requestBody = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart(
                        "file", file.name,
                        file.asRequestBody(getMimeType(filePath).toMediaType())
                    )
                    .build()

                // Get auth token from secure storage
                val token = ConfigManager.getAuthToken()
                
                val requestBuilder = Request.Builder()
                    .url("$baseUrl/upload")
                    .post(requestBody)
                
                // Add Authorization header if token exists
                if (!token.isNullOrEmpty()) {
                    Log.d(TAG, "Adding Authorization header to upload request")
                    requestBuilder.addHeader("Authorization", "Bearer $token")
                } else {
                    Log.w(TAG, "No auth token available - upload may fail with 401")
                }
                
                val request = requestBuilder.build()

                Log.d(TAG, "POST $baseUrl/upload")
                val response = withContext(Dispatchers.IO) { client.newCall(request).execute() }
                val responseBody = response.body?.string() ?: ""
                Log.d(TAG, "Response ${response.code}: $responseBody")

                if (response.isSuccessful) {
                    val uploadResponse = UploadResponse.fromJson(JSONObject(responseBody))
                    if (uploadResponse.success) {
                        Log.d(TAG, "Upload successful, file_id: ${uploadResponse.fileId}")
                        return uploadResponse
                    }
                    throw Exception(uploadResponse.message)
                }

                // Non-2xx — parse error body if possible
                val errorMessage = try {
                    JSONObject(responseBody).optString("message", "Upload failed with status ${response.code}")
                } catch (_: Exception) {
                    "Upload failed with status ${response.code}"
                }
                throw Exception(errorMessage)

            } catch (e: java.net.SocketException) {
                attempts++
                Log.e(TAG, "Network error (attempt $attempts): ${e.message}")
                if (attempts >= MAX_RETRY_ATTEMPTS)
                    throw Exception("Network error after $MAX_RETRY_ATTEMPTS attempts: ${e.message}")
                kotlinx.coroutines.delay((attempts * 2000).toLong())
            } catch (e: java.net.SocketTimeoutException) {
                attempts++
                Log.e(TAG, "Upload timeout (attempt $attempts)")
                if (attempts >= MAX_RETRY_ATTEMPTS)
                    throw Exception("Upload timeout after $MAX_RETRY_ATTEMPTS attempts")
                kotlinx.coroutines.delay((attempts * 2000).toLong())
            } catch (e: Exception) {
                Log.e(TAG, "Upload error: ${e.message}")
                throw Exception("Upload failed: ${e.message}")
            }
        }

        throw Exception("Upload failed after $MAX_RETRY_ATTEMPTS attempts")
    }

    /**
     * Upload multiple frame images to the /upload/video endpoint.
     *
     * @param framePaths Ordered list of frame file paths (max 60)
     * @return [VideoUploadResponse] with aggregated analysis
     * @throws Exception if frame count exceeds limit or all retries fail
     */
    suspend fun uploadFramesToVideoEndpoint(framePaths: List<String>): VideoUploadResponse {
        if (framePaths.isEmpty()) throw Exception("No frames to upload")
        if (framePaths.size > 60)
            throw Exception("Too many frames: ${framePaths.size}. Maximum is 60.")

        var attempts = 0

        while (attempts < MAX_RETRY_ATTEMPTS) {
            try {
                Log.d(TAG, "Uploading ${framePaths.size} frames to /upload/video (attempt ${attempts + 1}/$MAX_RETRY_ATTEMPTS)")

                val bodyBuilder = MultipartBody.Builder().setType(MultipartBody.FORM)

                framePaths.forEachIndexed { index, framePath ->
                    val file = File(framePath)
                    if (!file.exists()) throw Exception("Frame file not found: $framePath")
                    val mimeType = getMimeType(framePath)
                    if (!mimeType.startsWith("image/"))
                        throw Exception("Invalid frame format: $framePath (expected image file)")

                    bodyBuilder.addFormDataPart("files", file.name, file.asRequestBody(mimeType.toMediaType()))
                    Log.d(TAG, "Added frame $index: ${file.name} (${file.length()} bytes)")
                }

                // Get auth token from secure storage
                val token = ConfigManager.getAuthToken()
                
                val requestBuilder = Request.Builder()
                    .url("$baseUrl/upload/video")
                    .post(bodyBuilder.build())
                
                // Add Authorization header if token exists
                if (!token.isNullOrEmpty()) {
                    Log.d(TAG, "Adding Authorization header to video upload request")
                    requestBuilder.addHeader("Authorization", "Bearer $token")
                } else {
                    Log.w(TAG, "No auth token available - video upload may fail with 401")
                }
                
                val request = requestBuilder.build()

                Log.d(TAG, "POST $baseUrl/upload/video with ${framePaths.size} frames")
                val response = withContext(Dispatchers.IO) { client.newCall(request).execute() }
                val responseBody = response.body?.string() ?: ""
                Log.d(TAG, "Response ${response.code}: $responseBody")

                if (response.isSuccessful) {
                    val videoResponse = VideoUploadResponse.fromJson(JSONObject(responseBody))
                    if (videoResponse.error != null) throw Exception(videoResponse.error)
                    Log.d(TAG, "Video upload successful: prediction=${videoResponse.prediction}, confidence=${videoResponse.confidence}")
                    return videoResponse
                }

                val errorMessage = try {
                    val j = JSONObject(responseBody)
                    j.optString("error", j.optString("message", "Video upload failed with status ${response.code}"))
                } catch (_: Exception) {
                    "Video upload failed with status ${response.code}"
                }
                throw Exception(errorMessage)

            } catch (e: java.net.SocketException) {
                attempts++
                Log.e(TAG, "Network error (attempt $attempts): ${e.message}")
                if (attempts >= MAX_RETRY_ATTEMPTS)
                    throw Exception("Network error after $MAX_RETRY_ATTEMPTS attempts: ${e.message}")
                kotlinx.coroutines.delay((attempts * 2000).toLong())
            } catch (e: java.net.SocketTimeoutException) {
                attempts++
                Log.e(TAG, "Video upload timeout (attempt $attempts)")
                if (attempts >= MAX_RETRY_ATTEMPTS)
                    throw Exception("Video upload timeout after $MAX_RETRY_ATTEMPTS attempts")
                kotlinx.coroutines.delay((attempts * 2000).toLong())
            } catch (e: Exception) {
                Log.e(TAG, "Video upload error: ${e.message}")
                throw Exception("Video upload failed: ${e.message}")
            }
        }

        throw Exception("Video upload failed after $MAX_RETRY_ATTEMPTS attempts")
    }

    /**
     * Fetch the current analysis result for a given file ID.
     */
    suspend fun getAnalysisResult(fileId: String): AnalysisResult {
        Log.d(TAG, "Fetching analysis result for file_id: $fileId")
        try {
            val request = Request.Builder().url("$baseUrl/results/$fileId").get().build()
            val response = withContext(Dispatchers.IO) { client.newCall(request).execute() }
            val responseBody = response.body?.string() ?: ""
            Log.d(TAG, "Result ${response.code}: $responseBody")

            if (response.isSuccessful) return AnalysisResult.fromJson(JSONObject(responseBody))
            throw Exception("Failed to get result: ${response.code}")
        } catch (e: java.net.SocketTimeoutException) {
            Log.e(TAG, "Result fetch timeout")
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Result fetch error: ${e.message}")
            throw Exception("Failed to get analysis result: ${e.message}")
        }
    }

    /**
     * Poll /results/{fileId} until the job completes, fails, or times out.
     *
     * @param fileId        ID returned by [uploadFile]
     * @param timeout       Maximum wait in minutes (default [DEFAULT_TIMEOUT_MINUTES])
     * @param interval      Polling interval in seconds (default [DEFAULT_POLL_INTERVAL_SECONDS])
     * @param onStatusUpdate Optional callback invoked on each poll
     */
    suspend fun pollUntilComplete(
        fileId: String,
        timeout: Long = DEFAULT_TIMEOUT_MINUTES,
        interval: Long = DEFAULT_POLL_INTERVAL_SECONDS,
        onStatusUpdate: ((AnalysisResult) -> Unit)? = null
    ): AnalysisResult {
        Log.d(TAG, "Polling for file_id: $fileId (timeout=${timeout}min, interval=${interval}s)")
        val startTime = System.currentTimeMillis()
        var pollCount = 0

        while (true) {
            pollCount++
            val elapsed = (System.currentTimeMillis() - startTime) / 1000
            if (elapsed > timeout * 60) {
                Log.e(TAG, "Polling timeout after ${elapsed}s")
                throw Exception("Processing timeout after $timeout minutes")
            }
            Log.d(TAG, "Poll #$pollCount (${elapsed}s elapsed)")

            try {
                val result = getAnalysisResult(fileId)
                Log.d(TAG, "Status: ${result.status}, Label: ${result.label}, Confidence: ${result.confidence}")
                onStatusUpdate?.invoke(result)

                if (result.isCompleted) {
                    Log.d(TAG, "Processing completed")
                    return result
                }
                if (result.isFailed) {
                    Log.e(TAG, "Processing failed")
                    throw Exception(result.error ?: "Processing failed")
                }

                kotlinx.coroutines.delay(interval * 1000)
            } catch (e: java.net.SocketTimeoutException) {
                Log.e(TAG, "Transient timeout during poll: ${e.message}")
                kotlinx.coroutines.delay(interval * 1000)
            } catch (e: java.net.SocketException) {
                Log.e(TAG, "Transient network error during poll: ${e.message}")
                kotlinx.coroutines.delay(interval * 1000)
            } catch (e: Exception) {
                throw e
            }
        }
    }

    /**
     * Convenience wrapper: upload then poll until complete.
     */
    suspend fun uploadAndProcess(
        filePath: String,
        fileType: String,
        onStatusUpdate: ((AnalysisResult) -> Unit)? = null
    ): AnalysisResult {
        Log.d(TAG, "Starting upload-and-process flow")
        val uploadResponse = uploadFile(filePath, fileType)
        if (!uploadResponse.success) throw Exception(uploadResponse.message)
        return pollUntilComplete(uploadResponse.fileId, onStatusUpdate = onStatusUpdate)
    }

    /**
     * Upload media file with JWT authentication to /analyze/media endpoint.
     *
     * @param filePath Path to the media file
     * @param mediaType "image" or "video"
     * @param token Authentication token
     * @return JSONObject with analysis results
     * @throws Exception if upload fails
     */
    suspend fun uploadMediaWithAuth(filePath: String, mediaType: String, token: String): JSONObject {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Uploading media with auth: $filePath")

                val file = File(filePath)
                if (!file.exists()) throw Exception("File not found: $filePath")
                Log.d(TAG, "File size: ${file.length()} bytes")

                val requestBody = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart(
                        "file", file.name,
                        file.asRequestBody(getMimeType(filePath).toMediaType())
                    )
                    .addFormDataPart("type", mediaType)
                    .build()

                val request = Request.Builder()
                    .url("$baseUrl/analyze/media")
                    .addHeader("Authorization", "Bearer $token")
                    .post(requestBody)
                    .build()

                Log.d(TAG, "POST $baseUrl/analyze/media with auth")
                val response = client.newCall(request).execute()
                val responseBody = response.body?.string() ?: ""
                Log.d(TAG, "Response ${response.code}: $responseBody")

                if (response.isSuccessful) {
                    val jsonResponse = JSONObject(responseBody)
                    Log.d(TAG, "Authenticated upload successful")
                    return@withContext jsonResponse
                }

                // Handle authentication errors
                if (response.code == 401) {
                    throw Exception("Authentication failed. Please login again.")
                }

                // Parse error message
                val errorMessage = try {
                    JSONObject(responseBody).optString("detail", "Upload failed with status ${response.code}")
                } catch (_: Exception) {
                    "Upload failed with status ${response.code}"
                }
                throw Exception(errorMessage)

            } catch (e: Exception) {
                Log.e(TAG, "Upload error: ${e.message}")
                throw Exception("Upload failed: ${e.message}")
            }
        }
    }
}