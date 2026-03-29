package com.example.ai_fake_news_detector

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import androidx.annotation.GuardedBy
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.util.concurrent.locks.ReentrantLock

/**
 * Extracts frames from video at exactly 1 FPS using MediaExtractor and MediaCodec.
 * FIXED: Proper YUV format conversion to prevent crashes.
 */
class FrameExtractor private constructor(
    private val context: Context,
    private val videoPath: String,
    private val outputDir: File
) {
    companion object {
        private const val TAG = "FrameExtractor"
        private const val TARGET_FRAME_RATE = 1
        private const val MAX_VIDEO_DURATION_SECONDS = 45

        @Throws(IllegalArgumentException::class, IOException::class)
        fun create(
            context: Context,
            videoPath: String,
            outputDir: File
        ): FrameExtractor {
            val durationMs = getVideoDurationMs(videoPath)
            val durationSec = durationMs / 1000

            if (durationSec > MAX_VIDEO_DURATION_SECONDS) {
                throw IllegalArgumentException(
                    "Video duration ($durationSec seconds) exceeds maximum allowed " +
                            "duration of $MAX_VIDEO_DURATION_SECONDS seconds"
                )
            }

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
                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                    if (mime.startsWith("video/")) {
                        return if (format.containsKey(MediaFormat.KEY_DURATION))
                            format.getLong(MediaFormat.KEY_DURATION) / 1000
                        else 0L
                    }
                }
                return 0L
            } finally {
                extractor.release()
            }
        }
    }

    private val extractor = MediaExtractor()
    private var videoTrackIndex = -1
    private var videoFormat: MediaFormat? = null
    private var isRunning = false
    private val frameLock = ReentrantLock()

    @GuardedBy("frameLock")
    private val extractedFrames = mutableListOf<String>()

    private lateinit var videoCodec: MediaCodec

    init {
        extractor.setDataSource(videoPath)

        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("video/")) {
                videoTrackIndex = i
                videoFormat = format
                break
            }
        }

        if (videoTrackIndex == -1) {
            extractor.release()
            throw IllegalStateException("No video track found in the provided file")
        }

        val mime = videoFormat!!.getString(MediaFormat.KEY_MIME)!!
        videoCodec = MediaCodec.createDecoderByType(mime)
        videoCodec.configure(videoFormat, null, null, 0)
    }

    /**
     * FIXED: Converts MediaCodec YUV output to NV21 format that YuvImage can handle.
     * MediaCodec outputs various YUV formats (COLOR_FormatYUV420SemiPlanar=NV12, 
     * COLOR_FormatYUV420Planar=I420), but YuvImage only accepts NV21 (ImageFormat.NV21).
     */
    private fun convertToNV21(
        yuvData: ByteArray,
        width: Int,
        height: Int,
        colorFormat: Int
    ): ByteArray {
        val ySize = width * height
        val uvSize = width * height / 4 // UV plane is quarter size for 4:2:0
        
        val nv21 = ByteArray(ySize + 2 * uvSize) // Y + UV interleaved
        
        when (colorFormat) {
            // NV12: Y plane followed by UV interleaved (U then V)
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar,
            21 -> {
                // Copy Y plane as-is
                System.arraycopy(yuvData, 0, nv21, 0, ySize)
                
                // Convert UV interleaved (UVUV...) to VUVU... for NV21
                val uvStart = ySize
                val nv21UvStart = ySize
                var i = 0
                while (i < uvSize * 2) {
                    // NV12 has U then V, NV21 needs V then U
                    nv21[nv21UvStart + i] = yuvData[uvStart + i + 1] // V
                    nv21[nv21UvStart + i + 1] = yuvData[uvStart + i] // U
                    i += 2
                }
            }
            
            // I420 (YUV420Planar): Y plane, then U plane, then V plane (separate)
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar,
            19 -> {
                // Copy Y plane
                System.arraycopy(yuvData, 0, nv21, 0, ySize)
                
                // Interleave U and V planes into NV21 format (VU interleaved)
                val uStart = ySize
                val vStart = ySize + uvSize
                val nv21UvStart = ySize
                for (i in 0 until uvSize) {
                    nv21[nv21UvStart + i * 2] = yuvData[vStart + i]     // V first
                    nv21[nv21UvStart + i * 2 + 1] = yuvData[uStart + i] // U second
                }
            }
            
            else -> {
                // Fallback: assume data is already compatible or copy as-is
                // This may not work for all formats but prevents crash
                Log.w(TAG, "Unknown color format $colorFormat, attempting direct copy")
                if (yuvData.size >= nv21.size) {
                    System.arraycopy(yuvData, 0, nv21, 0, nv21.size)
                } else {
                    throw IllegalArgumentException("Unsupported color format: $colorFormat")
                }
            }
        }
        
        return nv21
    }

    fun extractFrames(
        onFrameExtracted: (timestampMs: Long, framePath: String) -> Unit,
        onProgressUpdate: (progress: Double) -> Unit,
        onCompletion: () -> Unit
    ) {
        frameLock.lock()
        isRunning = true
        frameLock.unlock()

        videoCodec.start()
        extractor.selectTrack(videoTrackIndex)

        var totalDurationMs = 0L
        var lastExtractedSecond = -1

        try {
            totalDurationMs = (videoFormat?.getLong(MediaFormat.KEY_DURATION) ?: 0L) / 1000

            var sawEOS = false
            var currentTimeMs = 0L

            while (isRunning && !sawEOS) {
                frameLock.lock()
                val running = isRunning
                frameLock.unlock()
                if (!running) break

                val inputBufferIndex = videoCodec.dequeueInputBuffer(10_000)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = videoCodec.getInputBuffer(inputBufferIndex)
                    val sampleSize = extractor.readSampleData(inputBuffer ?: return@extractFrames, 0)

                    if (sampleSize < 0) {
                        videoCodec.queueInputBuffer(
                            inputBufferIndex, 0, 0, 0,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        sawEOS = true
                    } else {
                        val presentationTimeUs = extractor.getSampleTime()
                        videoCodec.queueInputBuffer(
                            inputBufferIndex, 0, sampleSize, presentationTimeUs, 0
                        )
                        extractor.advance()
                    }
                }

                val bufferInfo = MediaCodec.BufferInfo()
                val outputBufferIndex = videoCodec.dequeueOutputBuffer(bufferInfo, 10_000)

                if (outputBufferIndex >= 0) {
                    val presentationTimeUs = bufferInfo.presentationTimeUs
                    currentTimeMs = presentationTimeUs / 1000

                    val currentSecond = (currentTimeMs / 1000).toInt()

                    if (currentSecond > lastExtractedSecond) {
                        val outputBuffer = videoCodec.getOutputBuffer(outputBufferIndex)
                        if (outputBuffer != null) {
                            val width = videoFormat?.getInteger(MediaFormat.KEY_WIDTH) ?: 0
                            val height = videoFormat?.getInteger(MediaFormat.KEY_HEIGHT) ?: 0

                            // FIXED: Get actual output format from the codec output
                            val outputFormat = videoCodec.getOutputFormat(outputBufferIndex)
                            val colorFormat = if (outputFormat.containsKey(MediaFormat.KEY_COLOR_FORMAT)) {
                                outputFormat.getInteger(MediaFormat.KEY_COLOR_FORMAT)
                            } else {
                                21 // Default to NV12/semi-planar
                            }

                            val bufferSize = outputBuffer.remaining()
                            val yuvData = ByteArray(bufferSize)
                            outputBuffer.get(yuvData)

                            // FIXED: Convert to NV21 format before creating YuvImage
                            val nv21Data = try {
                                convertToNV21(yuvData, width, height, colorFormat)
                            } catch (e: Exception) {
                                Log.e(TAG, "YUV conversion failed: ${e.message}")
                                videoCodec.releaseOutputBuffer(outputBufferIndex, false)
                                continue // Skip this frame but keep processing
                            }

                            // FIXED: Use ImageFormat.NV21 (17), not MediaCodec color format
                            val yuvImage = YuvImage(
                                nv21Data,
                                ImageFormat.NV21, // FIXED: Was using colorFormat directly!
                                width,
                                height,
                                null
                            )

                            val jpegStream = ByteArrayOutputStream()
                            val success = yuvImage.compressToJpeg(Rect(0, 0, width, height), 95, jpegStream)
                            
                            if (!success) {
                                Log.e(TAG, "JPEG compression failed for frame at ${currentTimeMs}ms")
                                videoCodec.releaseOutputBuffer(outputBufferIndex, false)
                                continue
                            }
                            
                            val jpegData = jpegStream.toByteArray()
                            val bitmap = BitmapFactory.decodeByteArray(jpegData, 0, jpegData.size)

                            if (bitmap == null) {
                                Log.e(TAG, "Bitmap decoding failed for frame at ${currentTimeMs}ms")
                                videoCodec.releaseOutputBuffer(outputBufferIndex, false)
                                continue
                            }

                            val frameFile = File(outputDir, "frame_${currentSecond}.png")
                            FileOutputStream(frameFile).use { stream ->
                                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            }

                            frameLock.lock()
                            extractedFrames.add(frameFile.absolutePath)
                            frameLock.unlock()

                            onFrameExtracted(currentTimeMs, frameFile.absolutePath)
                            Log.d(TAG, "Extracted frame at ${currentTimeMs}ms: ${frameFile.absolutePath}")

                            lastExtractedSecond = currentSecond
                            bitmap.recycle()
                        }

                        videoCodec.releaseOutputBuffer(outputBufferIndex, false)
                    } else {
                        videoCodec.releaseOutputBuffer(outputBufferIndex, false)
                    }

                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        sawEOS = true
                    }
                }

                val progress = if (totalDurationMs > 0)
                    (currentTimeMs.toDouble() / totalDurationMs).coerceIn(0.0, 1.0)
                else 0.0
                onProgressUpdate(progress)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during frame extraction: ${e.message}", e)
            throw e
        } finally {
            frameLock.lock()
            isRunning = false
            frameLock.unlock()

            try { videoCodec.stop() } catch (_: Exception) {}
            try { videoCodec.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}

            onCompletion()
        }
    }

    fun getExtractedFrames(): List<String> {
        frameLock.lock()
        try {
            return extractedFrames.toList()
        } finally {
            frameLock.unlock()
        }
    }

    fun cancel() {
        frameLock.lock()
        isRunning = false
        frameLock.unlock()
    }

    fun getVideoDurationSeconds(): Double =
        ((videoFormat?.getLong(MediaFormat.KEY_DURATION) ?: 0L) / 1_000_000.0)
}