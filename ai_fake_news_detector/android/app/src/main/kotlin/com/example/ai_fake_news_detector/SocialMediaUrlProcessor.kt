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

    enum class MediaType {
        IMAGE,
        VIDEO
    }

    data class ExtractedMedia(
        val mediaUrl: String,
        val platform: Platform,
        val mediaType: MediaType = MediaType.IMAGE
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

    suspend fun extractImageFromUrl(url: String): ExtractedMedia = withContext(Dispatchers.Main) {
        val platform = detectPlatform(url)
        
        if (platform == Platform.UNSUPPORTED) {
            throw UnsupportedOperationException("Unsupported platform for URL: $url")
        }

        var lastException: Exception? = null
        
        repeat(MAX_RETRIES + 1) { attempt ->
            try {
                Log.d(TAG, "Attempting to extract media (attempt ${attempt + 1}/${MAX_RETRIES + 1}): $url")
                
                val extractedMedia = when (platform) {
                    Platform.INSTAGRAM -> extractInstagramMedia(url)
                    Platform.FACEBOOK -> extractFacebookMedia(url)
                    else -> throw UnsupportedOperationException("Unsupported platform")
                }
                
                return@withContext extractedMedia
                
            } catch (e: Exception) {
                Log.e(TAG, "Extraction attempt ${attempt + 1} failed", e)
                lastException = e
                
                if (attempt < MAX_RETRIES) {
                    kotlinx.coroutines.delay(2000L * (attempt + 1))
                }
            }
        }
        
        throw lastException ?: Exception("Failed to extract media after $MAX_RETRIES retries")
    }

    private suspend fun extractInstagramMedia(url: String): ExtractedMedia = withContext(Dispatchers.Main) {
        var extractedUrl: String? = null
        var mediaType: MediaType = MediaType.IMAGE
        var error: String? = null
        val latch = CountDownLatch(1)

        val webView = WebView(context)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.loadWithOverviewMode = true
        webView.settings.useWideViewPort = true
        webView.settings.userAgentString = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        webView.addJavascriptInterface(
            object : Any() {
                @JavascriptInterface
                fun onMediaFound(url: String, type: String) {
                    Log.d(TAG, "JavaScript extracted media URL: $url, type: $type")
                    extractedUrl = url
                    mediaType = if (type.equals("video", ignoreCase = true)) MediaType.VIDEO else MediaType.IMAGE
                    latch.countDown()
                }

                @JavascriptInterface
                fun onError(message: String) {
                    Log.e(TAG, "JavaScript error: $message")
                    error = message
                    latch.countDown()
                }
            },
            "AndroidInterface"
        )

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                Log.d(TAG, "Instagram page finished loading, injecting JavaScript")
                
                val extractionScript = """
                    (function() {
                        try {
                            var mediaUrl = null;
                            var mediaType = 'image';
                            
                            var metaTags = document.querySelectorAll('meta[property="og:video"], meta[property="og:image"]');
                            if (metaTags.length > 0) {
                                for (var i = 0; i < metaTags.length; i++) {
                                    var content = metaTags[i].content;
                                    var property = metaTags[i].getAttribute('property');
                                    
                                    if (property === 'og:video' && content) {
                                        mediaUrl = content;
                                        mediaType = 'video';
                                        break;
                                    } else if (property === 'og:image' && content && !mediaUrl) {
                                        mediaUrl = content;
                                    }
                                }
                            }
                            
                            if (!mediaUrl) {
                                var videos = document.querySelectorAll('video');
                                if (videos.length > 0) {
                                    mediaUrl = videos[0].src;
                                    mediaType = 'video';
                                }
                            }
                            
                            if (!mediaUrl) {
                                var images = document.querySelectorAll('img');
                                for (var i = 0; i < images.length; i++) {
                                    var src = images[i].src;
                                    if (src && src.includes('cdninstagram.com') && !src.includes('profile')) {
                                        mediaUrl = src;
                                        mediaType = 'image';
                                        break;
                                    }
                                }
                            }
                            
                            if (mediaUrl) {
                                AndroidInterface.onMediaFound(mediaUrl, mediaType);
                            } else {
                                AndroidInterface.onError('No media found');
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

        val completed = withContext(Dispatchers.IO) {
            latch.await(EXTRACTION_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        }
        
        if (!completed) {
            Log.e(TAG, "WebView extraction timed out")
            error = "Extraction timed out after ${EXTRACTION_TIMEOUT_SECONDS}s"
        }
        
        withContext(Dispatchers.Main) {
            webView.destroy()
        }
        
        if (extractedUrl != null && extractedUrl!!.isNotBlank()) {
            Log.d(TAG, "Successfully extracted Instagram media: $extractedUrl, type: $mediaType")
            ExtractedMedia(extractedUrl!!, Platform.INSTAGRAM, mediaType)
        } else {
            val errorMsg = error ?: "Unknown extraction error"
            Log.e(TAG, "Extraction failed: $errorMsg")
            throw Exception("Failed to extract Instagram media: $errorMsg")
        }
    }

    private suspend fun extractFacebookMedia(url: String): ExtractedMedia = withContext(Dispatchers.Main) {
        var extractedUrl: String? = null
        var mediaType: MediaType = MediaType.IMAGE
        var error: String? = null
        val latch = CountDownLatch(1)

        val webView = WebView(context)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.loadWithOverviewMode = true
        webView.settings.useWideViewPort = true
        webView.settings.userAgentString = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        webView.addJavascriptInterface(
            object : Any() {
                @JavascriptInterface
                fun onMediaFound(url: String, type: String) {
                    Log.d(TAG, "JavaScript extracted Facebook media URL: $url, type: $type")
                    extractedUrl = url
                    mediaType = if (type.equals("video", ignoreCase = true)) MediaType.VIDEO else MediaType.IMAGE
                    latch.countDown()
                }

                @JavascriptInterface
                fun onError(message: String) {
                    Log.e(TAG, "JavaScript error: $message")
                    error = message
                    latch.countDown()
                }
            },
            "AndroidInterface"
        )

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                Log.d(TAG, "Facebook page finished loading")
                
                val extractionScript = """
                    (function() {
                        try {
                            var mediaUrl = null;
                            var mediaType = 'image';
                            
                            var metaTags = document.querySelectorAll('meta[property="og:video"], meta[property="og:video:url"], meta[property="og:image"]');
                            if (metaTags.length > 0) {
                                for (var i = 0; i < metaTags.length; i++) {
                                    var content = metaTags[i].content;
                                    var property = metaTags[i].getAttribute('property');
                                    
                                    if ((property === 'og:video' || property === 'og:video:url') && content) {
                                        mediaUrl = content;
                                        mediaType = 'video';
                                        break;
                                    } else if (property === 'og:image' && content && !mediaUrl) {
                                        mediaUrl = content;
                                    }
                                }
                            }
                            
                            if (!mediaUrl) {
                                var videos = document.querySelectorAll('video');
                                if (videos.length > 0) {
                                    mediaUrl = videos[0].src;
                                    mediaType = 'video';
                                }
                            }
                            
                            if (!mediaUrl) {
                                var images = document.querySelectorAll('img');
                                for (var i = 0; i < images.length; i++) {
                                    var src = images[i].src;
                                    if (src && (src.includes('fbcdn.net') || src.includes('facebook.com/photo'))) {
                                        mediaUrl = src;
                                        mediaType = 'image';
                                        break;
                                    }
                                }
                            }
                            
                            if (mediaUrl) {
                                AndroidInterface.onMediaFound(mediaUrl, mediaType);
                            } else {
                                AndroidInterface.onError('No media found');
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

        val completed = withContext(Dispatchers.IO) {
            latch.await(EXTRACTION_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        }
        
        if (!completed) {
            Log.e(TAG, "Facebook extraction timed out")
            error = "Extraction timed out after ${EXTRACTION_TIMEOUT_SECONDS}s"
        }
        
        withContext(Dispatchers.Main) {
            webView.destroy()
        }
        
        if (extractedUrl != null && extractedUrl!!.isNotBlank()) {
            Log.d(TAG, "Successfully extracted Facebook media: $extractedUrl, type: $mediaType")
            ExtractedMedia(extractedUrl!!, Platform.FACEBOOK, mediaType)
        } else {
            val errorMsg = error ?: "Unknown extraction error"
            Log.e(TAG, "Facebook extraction failed: $errorMsg")
            throw Exception("Failed to extract Facebook media: $errorMsg")
        }
    }

    private suspend fun extractInstagramImage(url: String): String {
        val media = extractInstagramMedia(url)
        return media.mediaUrl
    }

    private suspend fun extractFacebookImage(url: String): String {
        val media = extractFacebookMedia(url)
        return media.mediaUrl
    }

    suspend fun downloadMedia(mediaUrl: String, taskId: String, mediaType: MediaType): File = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Downloading ${if (mediaType == MediaType.VIDEO) "video" else "image"}: $mediaUrl")
            
            val request = Request.Builder()
                .url(mediaUrl)
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw Exception("Download failed with code: ${response.code}")
                }

                val body = response.body
                    ?: throw Exception("Empty response body")

                val contentType = response.header("Content-Type") ?: if (mediaType == MediaType.VIDEO) "video/mp4" else "image/jpeg"
                
                if (mediaType == MediaType.VIDEO) {
                    if (!contentType.startsWith("video/")) {
                        Log.w(TAG, "Expected video but got content type: $contentType")
                    }
                }
                
                val extension = when {
                    contentType.contains("mp4") || contentType.contains("mpeg") -> ".mp4"
                    contentType.contains("quicktime") -> ".mov"
                    contentType.contains("png") -> ".png"
                    contentType.contains("webp") -> ".webp"
                    contentType.contains("gif") -> ".gif"
                    else -> if (mediaType == MediaType.VIDEO) ".mp4" else ".jpg"
                }

                val cacheDir = File(context.cacheDir, "social_media_media")
                if (!cacheDir.exists()) {
                    cacheDir.mkdirs()
                }

                val outputFile = File(cacheDir, "media_${taskId}${extension}")
                
                FileOutputStream(outputFile).use { output ->
                    output.write(body.bytes())
                }

                Log.d(TAG, "Media downloaded successfully: ${outputFile.absolutePath}")
                outputFile
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to download media", e)
            throw Exception("Failed to download media: ${e.message}")
        }
    }

    suspend fun downloadImage(imageUrl: String, taskId: String): File {
        return downloadMedia(imageUrl, taskId, MediaType.IMAGE)
    }

    suspend fun uploadToBackend(mediaFile: File, taskId: String, token: String, mediaType: String = "image"): AnalysisResult {
        val uploadService = MediaUploadService()
        
        return try {
            Log.d(TAG, "Uploading extracted ${mediaType} to backend: ${mediaFile.absolutePath}")
            
            val response = uploadService.uploadMediaWithAuth(
                mediaFile.absolutePath,
                mediaType,
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
