package com.example.ai_fake_news_detector

import android.content.Context
import android.os.Build
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class SocialMediaUrlProcessor(
    private val context: Context
) {
    companion object {
        private const val TAG = "SocialMediaUrlProcessor"
        private const val EXTRACTION_TIMEOUT_SECONDS = 30L
        private const val MAX_RETRIES = 2
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    enum class Platform {
        INSTAGRAM,
        FACEBOOK,
        UNSUPPORTED
    }

    data class ExtractedImage(
        val imageUrl: String,
        val platform: Platform
    )

    private class ImageExtractionInterface(
        private val onImageExtracted: (String) -> Unit,
        private val onError: (String) -> Unit
    ) {
        @JavascriptInterface
        fun onImageFound(url: String) {
            onImageExtracted(url)
        }

        @JavascriptInterface
        fun onError(message: String) {
            onError(message)
        }
    }

    fun detectPlatform(url: String): Platform {
        return when {
            url.contains("instagram.com", ignoreCase = true) -> Platform.INSTAGRAM
            url.contains("facebook.com", ignoreCase = true) ||
            url.contains("fb.com", ignoreCase = true) ||
            url.contains("fb.watch", ignoreCase = true) -> Platform.FACEBOOK
            else -> Platform.UNSUPPORTED
        }
    }

    suspend fun extractImageFromUrl(url: String): ExtractedImage = withContext(Dispatchers.Main) {
        val platform = detectPlatform(url)
        
        if (platform == Platform.UNSUPPORTED) {
            throw UnsupportedOperationException("Unsupported platform for URL: $url")
        }

        var lastException: Exception? = null
        
        repeat(MAX_RETRIES + 1) { attempt ->
            try {
                Log.d(TAG, "Attempting to extract image (attempt ${attempt + 1}/${MAX_RETRIES + 1}): $url")
                
                val imageUrl = when (platform) {
                    Platform.INSTAGRAM -> extractInstagramImage(url)
                    Platform.FACEBOOK -> extractFacebookImage(url)
                    else -> throw UnsupportedOperationException("Unsupported platform")
                }
                
                return@withContext ExtractedImage(imageUrl, platform)
                
            } catch (e: Exception) {
                Log.e(TAG, "Extraction attempt ${attempt + 1} failed", e)
                lastException = e
                
                if (attempt < MAX_RETRIES) {
                    kotlinx.coroutines.delay(2000L * (attempt + 1))
                }
            }
        }
        
        throw lastException ?: Exception("Failed to extract image after $MAX_RETRIES retries")
    }

    private suspend fun extractInstagramImage(url: String): String = suspendCancellableCoroutine { continuation ->
        var extractedUrl: String? = null
        var error: String? = null
        val latch = CountDownLatch(1)

        val webView = WebView(context)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.loadWithOverviewMode = true
        webView.settings.useWideViewPort = true
        webView.settings.userAgentString = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        webView.addJavascriptInterface(
            ImageExtractionInterface(
                onImageExtracted = { url ->
                    Log.d(TAG, "JavaScript extracted image URL: $url")
                    extractedUrl = url
                    latch.countDown()
                },
                onError = { errorMessage ->
                    Log.e(TAG, "JavaScript error: $errorMessage")
                    error = errorMessage
                    latch.countDown()
                }
            ),
            "AndroidInterface"
        )

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                Log.d(TAG, "Page finished loading, injecting JavaScript")
                
                val extractionScript = """
                    (function() {
                        try {
                            var imageUrl = null;
                            
                            var metaTags = document.querySelectorAll('meta[property="og:image"], meta[property="twitter:image"]');
                            if (metaTags.length > 0) {
                                imageUrl = metaTags[0].content;
                            }
                            
                            if (!imageUrl) {
                                var images = document.querySelectorAll('img');
                                for (var i = 0; i < images.length; i++) {
                                    var src = images[i].src;
                                    if (src && src.includes('cdninstagram.com') && !src.includes('profile')) {
                                        imageUrl = src;
                                        break;
                                    }
                                }
                            }
                            
                            if (imageUrl) {
                                AndroidInterface.onImageFound(imageUrl);
                            } else {
                                AndroidInterface.onError('No image found');
                            }
                        } catch(e) {
                            AndroidInterface.onError(e.message);
                        }
                    })();
                """.trimIndent()
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    webView.evaluateJavascript(extractionScript, null)
                } else {
                    webView.loadUrl("javascript:$extractionScript")
                }
            }

            override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
                Log.e(TAG, "WebView error: $description")
                error = description ?: "Failed to load page"
                latch.countDown()
            }
        }

        try {
            Log.d(TAG, "Loading Instagram URL in WebView: $url")
            webView.loadUrl(url)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load URL", e)
            error = e.message
            latch.countDown()
        }

        continuation.invokeOnCancellation {
            Log.d(TAG, "Extraction cancelled, destroying WebView")
            webView.destroy()
        }

        Thread {
            val completed = latch.await(EXTRACTION_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            
            if (!completed) {
                Log.e(TAG, "WebView extraction timed out")
                error = "Extraction timed out after ${EXTRACTION_TIMEOUT_SECONDS}s"
            }
            
            webView.post {
                webView.destroy()
            }
            
            if (continuation.isActive) {
                if (extractedUrl != null && extractedUrl!!.isNotBlank()) {
                    Log.d(TAG, "Successfully extracted Instagram image: $extractedUrl")
                    continuation.resume(extractedUrl!!)
                } else {
                    val errorMsg = error ?: "Unknown extraction error"
                    Log.e(TAG, "Extraction failed: $errorMsg")
                    continuation.resumeWithException(Exception("Failed to extract Instagram image: $errorMsg"))
                }
            }
        }.start()
    }

    private suspend fun extractFacebookImage(url: String): String = suspendCancellableCoroutine { continuation ->
        var extractedUrl: String? = null
        var error: String? = null
        val latch = CountDownLatch(1)

        val webView = WebView(context)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.loadWithOverviewMode = true
        webView.settings.useWideViewPort = true
        webView.settings.userAgentString = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        webView.addJavascriptInterface(
            ImageExtractionInterface(
                onImageExtracted = { url ->
                    Log.d(TAG, "JavaScript extracted Facebook image URL: $url")
                    extractedUrl = url
                    latch.countDown()
                },
                onError = { errorMessage ->
                    Log.e(TAG, "JavaScript error: $errorMessage")
                    error = errorMessage
                    latch.countDown()
                }
            ),
            "AndroidInterface"
        )

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                Log.d(TAG, "Facebook page finished loading")
                
                val extractionScript = """
                    (function() {
                        try {
                            var imageUrl = null;
                            
                            var metaTags = document.querySelectorAll('meta[property="og:image"], meta[property="twitter:image"]');
                            if (metaTags.length > 0) {
                                imageUrl = metaTags[0].content;
                            }
                            
                            if (!imageUrl) {
                                var images = document.querySelectorAll('img');
                                for (var i = 0; i < images.length; i++) {
                                    var src = images[i].src;
                                    if (src && (src.includes('fbcdn.net') || src.includes('facebook.com/photo'))) {
                                        imageUrl = src;
                                        break;
                                    }
                                }
                            }
                            
                            if (imageUrl) {
                                AndroidInterface.onImageFound(imageUrl);
                            } else {
                                AndroidInterface.onError('No image found');
                            }
                        } catch(e) {
                            AndroidInterface.onError(e.message);
                        }
                    })();
                """.trimIndent()
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    webView.evaluateJavascript(extractionScript, null)
                } else {
                    webView.loadUrl("javascript:$extractionScript")
                }
            }

            override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
                Log.e(TAG, "WebView error: $description")
                error = description ?: "Failed to load Facebook page"
                latch.countDown()
            }
        }

        try {
            Log.d(TAG, "Loading Facebook URL in WebView: $url")
            webView.loadUrl(url)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load Facebook URL", e)
            error = e.message
            latch.countDown()
        }

        continuation.invokeOnCancellation {
            Log.d(TAG, "Facebook extraction cancelled, destroying WebView")
            webView.destroy()
        }

        Thread {
            val completed = latch.await(EXTRACTION_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            
            if (!completed) {
                Log.e(TAG, "Facebook extraction timed out")
                error = "Extraction timed out after ${EXTRACTION_TIMEOUT_SECONDS}s"
            }
            
            webView.post {
                webView.destroy()
            }
            
            if (continuation.isActive) {
                if (extractedUrl != null && extractedUrl!!.isNotBlank()) {
                    Log.d(TAG, "Successfully extracted Facebook image: $extractedUrl")
                    continuation.resume(extractedUrl!!)
                } else {
                    val errorMsg = error ?: "Unknown extraction error"
                    Log.e(TAG, "Facebook extraction failed: $errorMsg")
                    continuation.resumeWithException(Exception("Failed to extract Facebook image: $errorMsg"))
                }
            }
        }.start()
    }

    suspend fun downloadImage(imageUrl: String, taskId: String): File = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Downloading image: $imageUrl")
            
            val request = Request.Builder()
                .url(imageUrl)
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw Exception("Download failed with code: ${response.code}")
                }

                val body = response.body
                    ?: throw Exception("Empty response body")

                val contentType = response.header("Content-Type") ?: "image/jpeg"
                val extension = when {
                    contentType.contains("png") -> ".png"
                    contentType.contains("webp") -> ".webp"
                    contentType.contains("gif") -> ".gif"
                    else -> ".jpg"
                }

                val cacheDir = File(context.cacheDir, "social_media_images")
                if (!cacheDir.exists()) {
                    cacheDir.mkdirs()
                }

                val outputFile = File(cacheDir, "image_${taskId}${extension}")
                
                FileOutputStream(outputFile).use { output ->
                    output.write(body.bytes())
                }

                Log.d(TAG, "Image downloaded successfully: ${outputFile.absolutePath}")
                outputFile
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to download image", e)
            throw Exception("Failed to download image: ${e.message}")
        }
    }

    suspend fun uploadToBackend(imageFile: File, taskId: String, token: String): AnalysisResult {
        val uploadService = MediaUploadService()
        
        return try {
            Log.d(TAG, "Uploading extracted image to backend: ${imageFile.absolutePath}")
            
            val response = uploadService.uploadMediaWithAuth(
                imageFile.absolutePath,
                "image",
                token
            )

            val data = response.optJSONObject("data")
            if (data != null) {
                AnalysisResult(
                    fileId = data.optString("analysis_id", taskId),
                    status = "completed",
                    label = data.optString("prediction", ""),
                    confidence = data.optDouble("confidence", 0.0).takeIf { !it.isNaN() },
                    processingTime = 0.0
                )
            } else {
                val fileId = response.optString("file_id", taskId)
                uploadService.pollUntilComplete(fileId)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Upload to backend failed", e)
            throw Exception("Upload failed: ${e.message}")
        }
    }

    fun cleanupTempFile(file: File) {
        try {
            if (file.exists()) {
                file.delete()
                Log.d(TAG, "Cleaned up temporary file: ${file.absolutePath}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cleanup temp file", e)
        }
    }
}
