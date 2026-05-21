package com.example.ai_fake_news_detector

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * NotificationMediaHelper - Handles notification media (images/thumbnails)
 * 
 * Provides:
 * - BigPictureStyle setup with proper bitmap sizing
 * - Remote image downloading and caching
 * - Memory-efficient bitmap decoding
 * - Comprehensive error handling
 */
object NotificationMediaHelper {
    private const val TAG = "NotificationMediaHelper"
    private const val MAX_IMAGE_WIDTH = 1024
    private const val MAX_IMAGE_HEIGHT = 1024
    private const val CACHE_MAX_AGE_HOURS = 24
    
    private var cacheDir: File? = null
    
    /**
     * Initialize cache directory
     */
    fun init(context: Context) {
        cacheDir = File(context.cacheDir, "notification_media")
        if (!cacheDir!!.exists()) {
            cacheDir!!.mkdirs()
            Log.d(TAG, "Created notification media cache directory")
        }
        cleanOldCache()
    }
    
    /**
     * Apply BigPictureStyle to notification with local image
     * 
     * @param builder Notification builder to modify
     * @param imagePath Local file path to image
     * @return true if BigPictureStyle was successfully applied
     */
    fun applyBigPictureStyle(
        builder: NotificationCompat.Builder,
        imagePath: String
    ): Boolean {
        return try {
            val bitmap = decodeSampledBitmap(imagePath, MAX_IMAGE_WIDTH, MAX_IMAGE_HEIGHT)
            if (bitmap != null) {
                builder.setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(bitmap)
                        .bigLargeIcon(null as Bitmap?)
                )
                Log.d(TAG, "BigPictureStyle applied successfully for local image")
                true
            } else {
                Log.w(TAG, "Failed to decode bitmap from: $imagePath")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error applying BigPictureStyle for local image: ${e.message}")
            false
        }
    }
    
    /**
     * Apply BigPictureStyle with thumbnail from video file
     * 
     * Uses native MediaStore API for efficient thumbnail extraction
     * 
     * @param builder Notification builder to modify
     * @param videoPath Local video file path
     * @return true if BigPictureStyle was successfully applied
     */
    fun applyVideoThumbnailStyle(
        builder: NotificationCompat.Builder,
        videoPath: String
    ): Boolean {
        return try {
            // Use ThumbnailUtils for efficient video frame extraction
            val bitmap = android.media.ThumbnailUtils.createVideoThumbnail(
                videoPath,
                android.provider.MediaStore.Images.Thumbnails.FULL_SCREEN_KIND
            )
            
            if (bitmap != null) {
                builder.setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(bitmap)
                        .bigLargeIcon(null as Bitmap?)
                )
                Log.d(TAG, "BigPictureStyle applied successfully for video")
                true
            } else {
                Log.w(TAG, "ThumbnailUtils returned null for video: $videoPath")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting video thumbnail: ${e.message}")
            false
        }
    }
    
    /**
     * Download remote image and apply BigPictureStyle
     * 
     * Handles:
     * - Network image downloading with timeout
     * - File caching to avoid repeated downloads
     * - Memory-efficient bitmap decoding
     * - Proper error handling
     * 
     * @param builder Notification builder to modify
     * @param imageUrl Remote image URL
     * @return true if download and style application succeeded
     */
    suspend fun downloadAndApplyBigPictureStyle(
        builder: NotificationCompat.Builder,
        imageUrl: String
    ): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                if (cacheDir == null) {
                    Log.w(TAG, "Cache directory not initialized")
                    return@withContext false
                }
                
                // Check cache first
                val cachedFile = getCachedImage(imageUrl)
                if (cachedFile != null && cachedFile.exists()) {
                    Log.d(TAG, "Using cached image for URL: $imageUrl")
                    return@withContext applyBigPictureStyle(builder, cachedFile.absolutePath)
                }
                
                // Download image
                val downloadedFile = downloadImage(imageUrl)
                if (downloadedFile != null && downloadedFile.exists()) {
                    Log.d(TAG, "Successfully downloaded and cached image")
                    return@withContext applyBigPictureStyle(builder, downloadedFile.absolutePath)
                }
                
                Log.w(TAG, "Failed to download image: $imageUrl")
                false
            } catch (e: Exception) {
                Log.e(TAG, "Error in downloadAndApplyBigPictureStyle: ${e.message}")
                false
            }
        }
    }
    
    /**
     * Decode a Bitmap with memory-efficient subsampling
     * 
     * Prevents OutOfMemory errors by:
     * - Reading bitmap dimensions without loading full image
     * - Calculating appropriate inSampleSize
     * - Loading with downsampled dimensions
     * 
     * @param filePath Path to image file
     * @param reqWidth Required width
     * @param reqHeight Required height
     * @return Decoded bitmap or null if failed
     */
    private fun decodeSampledBitmap(
        filePath: String,
        reqWidth: Int,
        reqHeight: Int
    ): Bitmap? {
        return try {
            val options = BitmapFactory.Options()
            
            // First, decode with inJustDecodeBounds to get dimensions without loading full image
            options.inJustDecodeBounds = true
            BitmapFactory.decodeFile(filePath, options)
            
            if (options.outWidth == 0 || options.outHeight == 0) {
                Log.w(TAG, "Invalid bitmap dimensions: ${options.outWidth}x${options.outHeight}")
                return null
            }
            
            // Calculate inSampleSize
            options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight)
            
            // Now decode with inJustDecodeBounds set to false to load the actual bitmap
            options.inJustDecodeBounds = false
            options.inPreferredConfig = Bitmap.Config.RGB_565 // Use RGB_565 to save memory
            
            val bitmap = BitmapFactory.decodeFile(filePath, options)
            
            if (bitmap == null) {
                Log.w(TAG, "BitmapFactory.decodeFile returned null for: $filePath")
            }
            
            bitmap
        } catch (e: Exception) {
            Log.e(TAG, "Error decoding bitmap from $filePath: ${e.message}")
            null
        }
    }
    
    /**
     * Calculate optimal inSampleSize for bitmap downsampling
     * 
     * Powers of 2 are preferred for efficiency
     */
    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1
        
        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        
        return inSampleSize
    }
    
    /**
     * Download image from URL with timeout
     * 
     * @param imageUrl Remote image URL
     * @return Downloaded file or null if failed
     */
    private suspend fun downloadImage(imageUrl: String): File? {
        return withContext(Dispatchers.IO) {
            try {
                val cacheFile = File(cacheDir, "${imageUrl.hashCode()}.jpg")
                
                // Check if already cached
                if (cacheFile.exists()) {
                    val age = System.currentTimeMillis() - cacheFile.lastModified()
                    if (age < TimeUnit.HOURS.toMillis(CACHE_MAX_AGE_HOURS.toLong())) {
                        return@withContext cacheFile
                    } else {
                        cacheFile.delete()
                    }
                }
                
                Log.d(TAG, "Downloading image from: $imageUrl")
                
                val url = URL(imageUrl)
                val connection = url.openConnection()
                connection.connectTimeout = 10000 // 10 seconds
                connection.readTimeout = 10000
                
                val inputStream = connection.getInputStream()
                val bitmap = BitmapFactory.decodeStream(inputStream)
                inputStream.close()
                
                if (bitmap != null) {
                    // Save to cache
                    FileOutputStream(cacheFile).use { fos ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, fos)
                    }
                    
                    Log.d(TAG, "Image cached successfully at: ${cacheFile.absolutePath}")
                    cacheFile
                } else {
                    Log.w(TAG, "Failed to decode downloaded image")
                    null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error downloading image: ${e.message}")
                null
            }
        }
    }
    
    /**
     * Get cached image file for URL
     */
    private fun getCachedImage(imageUrl: String): File? {
        if (cacheDir == null) return null
        
        val cacheFile = File(cacheDir, "${imageUrl.hashCode()}.jpg")
        return if (cacheFile.exists()) cacheFile else null
    }
    
    /**
     * Clean old cache files
     */
    private fun cleanOldCache() {
        try {
            if (cacheDir == null || !cacheDir!!.exists()) return
            
            val maxAge = TimeUnit.HOURS.toMillis(CACHE_MAX_AGE_HOURS.toLong())
            val now = System.currentTimeMillis()
            
            cacheDir!!.listFiles()?.forEach { file ->
                if (file.isFile && (now - file.lastModified()) > maxAge) {
                    file.delete()
                    Log.d(TAG, "Deleted old cache file: ${file.name}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning cache: ${e.message}")
        }
    }
}
