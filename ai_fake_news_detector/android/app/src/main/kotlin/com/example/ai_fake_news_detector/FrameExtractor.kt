package com.example.ai_fake_news_detector

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import androidx.annotation.GuardedBy
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.util.concurrent.locks.ReentrantLock

/**
 * Extracts frames from video at exactly 1 FPS using MediaExtractor and MediaCodec.
 * This ensures we get true full frames from the video at each second timestamp
 * without interpolation, alteration, or reconstruction.
 */
class FrameExtractor private constructor(
    private val context: Context,
    private val videoPath: String,
    private val outputDir: File
) {
    companion object {
        private const val TAG = "FrameExtractor"
        private const val TARGET_FRAME_RATE = 1 // 1 frame per second
        private const val MAX_VIDEO_DURATION_SECONDS = 45
        
        /**
         * Creates a FrameExtractor instance and validates the video.
         *
         * @param context Android context
         * @param videoPath Path to the video file
         * @param outputDir Directory to save extracted frames
         * @return FrameExtractor instance
         * @throws IllegalArgumentException if video is invalid or too long
         * @throws IOException if there's an error accessing the video
         */
        @Throws(IllegalArgumentException::class, IOException::class)
        fun create(
            context: Context,
            videoPath: String,
            outputDir: File
        ): FrameExtractor {
            // Validate video duration first
            val durationMs = getVideoDurationMs(videoPath)
            val durationSec = durationMs / 1000
            
            if (durationSec > MAX_VIDEO_DURATION_SECONDS) {
                throw IllegalArgumentException(
                    "Video duration ($durationSec seconds) exceeds maximum allowed " +
                            "duration of $MAX_VIDEO_DURATION_SECONDS seconds"
                )
            }
            
            // Validate that we can read the video
            MediaExtractor().apply {
                setDataSource(videoPath)
                release()
            }
            
            return FrameExtractor(context, videoPath, outputDir)
        }
        
        private fun getVideoDurationMs(videoPath: String): Long {
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(videoPath)
                val format = extractor.getTrackFormat(0) // Assume first track is video
                return format?.getLong(MediaFormat.KEY_DURATION) ?: 0
            } finally {
                extractor.release()
            }
        }
    }
    
    private val extractor = MediaExtractor()
    private val videoCodec = MediaCodec.createDecoderByType("video/avc") // H.264
    private var videoTrackIndex = -1
    private var videoFormat: MediaFormat? = null
    private var isRunning = false
    private val frameLock = ReentrantLock()
    
    @GuardedBy("frameLock")
    private val extractedFrames = mutableListOf<String>()
    
    init {
        // Initialize extractor and find video track
        extractor.setDataSource(videoPath)
        
        val trackCount = extractor.trackCount
        for (i in 0 until trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("video/")) {
                videoTrackIndex = i
                videoFormat = format
                break
            }
        }
        
        if (videoTrackIndex == -1) {
            throw IllegalStateException("No video track found in the provided file")
        }
        
        // Configure the decoder
        videoCodec.configure(videoFormat, null, null, 0)
    }
    
    /**
     * Extracts frames at exactly 1 FPS and saves them to the output directory.
     *
     * @param onFrameExtracted Callback for each extracted frame with timestamp and file path
     * @param onProgressUpdate Callback for progress updates (0.0 to 1.0)
     * @param onCompletion Callback when extraction is complete
     */
    fun extractFrames(
        onFrameExtracted: (timestampMs: Long, framePath: String) -> Unit,
        onProgressUpdate: (progress: Double) -> Unit,
        onCompletion: () -> Unit
    ) {
        frameLock.lock()
        isRunning = true
        frameLock.unlock()
        
        // Start the decoder
        videoCodec.start()
        
        // Select the video track
        extractor.selectTrack(videoTrackIndex)
        
        val startTimeMs = System.currentTimeMillis()
        var totalDurationMs = 0L
        var lastExtractedSecond = -1
        
        try {
            // Get video duration for progress calculation
            totalDurationMs = videoFormat?.getLong(MediaFormat.KEY_DURATION) ?: 0L
            
            var inputBufferIndex: Int
            var outputBufferIndex: Int
            var bufferInfo: MediaCodec.BufferInfo
            var sawEOS = false
            var currentTimeMs = 0L
            
            while (isRunning && !sawEOS) {
                // Check if we should stop due to cancellation
                frameLock.lock()
                val running = isRunning
                frameLock.unlock()
                
                if (!running) break
                
                // Feed input buffer to decoder
                inputBufferIndex = videoCodec.dequeueInputBuffer(10_000)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = videoCodec.getInputBuffer(inputBufferIndex)
                    val sampleSize = extractor.readSampleData(
                        inputBuffer ?: return@extractFrames, 0
                    )
                    
                    if (sampleSize < 0) {
                        // End of stream
                        videoCodec.queueInputBuffer(
                            inputBufferIndex,
                            0,
                            0,
                            0,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        sawEOS = true
                    } else {
                        val presentationTimeUs = extractor.getSampleTime()
                        videoCodec.queueInputBuffer(
                            inputBufferIndex,
                            0,
                            sampleSize,
                            presentationTimeUs,
                            0
                        )
                        extractor.advance()
                    }
                }
                
                // Get output buffer from decoder
                bufferInfo = MediaCodec.BufferInfo()
                outputBufferIndex = videoCodec.dequeueOutputBuffer(bufferInfo, 10_000)
                
                if (outputBufferIndex >= 0) {
                    val presentationTimeUs = bufferInfo.presentationTimeUs
                    currentTimeMs = presentationTimeUs / 1000
                    
                    // Check if we should extract a frame at this timestamp (1 FPS)
                    val currentSecond = (currentTimeMs / 1000).toInt()
                    if (currentSecond > lastExtractedSecond) {
                        // Extract frame at this second
                        val outputBuffer = videoCodec.getOutputBuffer(outputBufferIndex)
                        if (outputBuffer != null) {
                            val bitmap = Bitmap.createBitmap(
                                videoFormat?.getInteger(MediaFormat.KEY_WIDTH) ?: 0,
                                videoFormat?.getInteger(MediaFormat.KEY_HEIGHT) ?: 0,
                                Bitmap.Config.ARGB_8888
                            )
                            
                            // Copy the buffer to bitmap
                            val pixelCount = (videoFormat?.getInteger(MediaFormat.KEY_WIDTH) ?: 0) *
                                    (videoFormat?.getInteger(MediaFormat.KEY_HEIGHT) ?: 0)
                            val pixelBuffer = ByteArray(pixelCount * 4) // ARGB
                            outputBuffer.position(0)
                            outputBuffer.get(pixelBuffer, 0, pixelBuffer.size)
                            
                            bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(pixelBuffer))
                            
                            // Save bitmap as PNG
                            val frameFile = File(
                                outputDir,
                                "frame_${currentSecond}.png"
                            )
                            FileOutputStream(frameFile).use { stream ->
                                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            }
                            
                            // Notify about extracted frame
                            frameLock.lock()
                            extractedFrames.add(frameFile.absolutePath)
                            frameLock.unlock()
                            
                            onFrameExtracted(currentTimeMs, frameFile.absolutePath)
                            Log.d(TAG, "Extracted frame at $currentTimeMs ms: ${frameFile.absolutePath}")
                            
                            lastExtractedSecond = currentSecond
                            
                            bitmap.recycle()
                        }
                        
                        videoCodec.releaseOutputBuffer(outputBufferIndex, false)
                    } else if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        sawEOS = true
                    } else {
                        videoCodec.releaseOutputBuffer(outputBufferIndex, false)
                    }
                } else if (outputBufferIndex == MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED) {
                    // Not important for us
                } else if (outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    // Not important for us
                }
                
                // Update progress
                val progress = if (totalDurationMs > 0) {
                    Math.min(1.0, currentTimeMs.toDouble() / totalDurationMs)
                } else {
                    0.0
                }
                onProgressUpdate(progress)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during frame extraction: ${e.message}", e)
            throw e
        } finally {
            // Clean up resources
            frameLock.lock()
            isRunning = false
            frameLock.unlock()
            
            videoCodec.stop()
            videoCodec.release()
            extractor.release()
            
            onCompletion()
        }
    }
    
    /**
     * Gets the list of extracted frame file paths.
     *
     * @return List of absolute file paths to extracted frames
     */
    fun getExtractedFrames(): List<String> {
        frameLock.lock()
        val result = mutableListOf<String>()
        for (frame in extractedFrames) {
            result.add(frame)
        }
        frameLock.unlock()
        return result.toList()
    }
    
    /**
     * Cancels the frame extraction process.
     */
    fun cancel() {
        frameLock.lock()
        isRunning = false
        frameLock.unlock()
    }
    
    /**
     * Gets the video duration in seconds.
     *
     * @return Video duration in seconds
     */
    fun getVideoDurationSeconds(): Double {
        return (videoFormat?.getLong(MediaFormat.KEY_DURATION) ?: 0L) / 1000.0
    }
}
