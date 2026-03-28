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
            val durationMs  = getVideoDurationMs(videoPath)
            val durationSec = durationMs / 1000

            if (durationSec > MAX_VIDEO_DURATION_SECONDS) {
                throw IllegalArgumentException(
                    "Video duration ($durationSec seconds) exceeds maximum allowed " +
                            "duration of $MAX_VIDEO_DURATION_SECONDS seconds"
                )
            }

            // Validate readability
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
                // Search all tracks for the video track duration
                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime   = format.getString(MediaFormat.KEY_MIME) ?: continue
                    if (mime.startsWith("video/")) {
                        return if (format.containsKey(MediaFormat.KEY_DURATION))
                            format.getLong(MediaFormat.KEY_DURATION) / 1000 // µs → ms
                        else 0L
                    }
                }
                return 0L
            } finally {
                extractor.release()
            }
        }
    }

    private val extractor    = MediaExtractor()
    private var videoTrackIndex = -1
    private var videoFormat: MediaFormat? = null
    private var isRunning    = false
    private val frameLock    = ReentrantLock()

    @GuardedBy("frameLock")
    private val extractedFrames = mutableListOf<String>()

    // FIX: videoCodec must NOT be initialised here with a hardcoded MIME type.
    // The correct MIME is only known after we inspect the video track in init{}.
    // Declaring it as lateinit and assigning it inside init{} after track detection
    // means we support H.264, H.265/HEVC, VP8, VP9, AV1, and any other codec the
    // device supports — not just "video/avc".
    private lateinit var videoCodec: MediaCodec

    init {
        extractor.setDataSource(videoPath)

        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime   = format.getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("video/")) {
                videoTrackIndex = i
                videoFormat     = format
                break
            }
        }

        if (videoTrackIndex == -1) {
            extractor.release()
            throw IllegalStateException("No video track found in the provided file")
        }

        // FIX: derive codec from the actual track MIME type, not a hardcoded constant.
        val mime = videoFormat!!.getString(MediaFormat.KEY_MIME)!!
        videoCodec = MediaCodec.createDecoderByType(mime)
        videoCodec.configure(videoFormat, null, null, 0)
    }

    /**
     * Extracts frames at exactly 1 FPS and saves them to the output directory.
     *
     * @param onFrameExtracted Callback for each extracted frame with timestamp and file path
     * @param onProgressUpdate Callback for progress updates (0.0 to 1.0)
     * @param onCompletion     Callback when extraction is complete
     */
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

        var totalDurationMs  = 0L
        var lastExtractedSecond = -1

        try {
            totalDurationMs = (videoFormat?.getLong(MediaFormat.KEY_DURATION) ?: 0L) / 1000 // µs → ms

            var sawEOS       = false
            var currentTimeMs = 0L

            while (isRunning && !sawEOS) {
                frameLock.lock()
                val running = isRunning
                frameLock.unlock()
                if (!running) break

                // Feed input
                val inputBufferIndex = videoCodec.dequeueInputBuffer(10_000)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = videoCodec.getInputBuffer(inputBufferIndex)
                    val sampleSize  = extractor.readSampleData(inputBuffer ?: return@extractFrames, 0)

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

                // Drain output
                val bufferInfo       = MediaCodec.BufferInfo()
                val outputBufferIndex = videoCodec.dequeueOutputBuffer(bufferInfo, 10_000)

                if (outputBufferIndex >= 0) {
                    val presentationTimeUs = bufferInfo.presentationTimeUs
                    currentTimeMs = presentationTimeUs / 1000

                    val currentSecond = (currentTimeMs / 1000).toInt()

                    if (currentSecond > lastExtractedSecond) {
                        val outputBuffer = videoCodec.getOutputBuffer(outputBufferIndex)
                        if (outputBuffer != null) {
                            val width  = videoFormat?.getInteger(MediaFormat.KEY_WIDTH)  ?: 0
                            val height = videoFormat?.getInteger(MediaFormat.KEY_HEIGHT) ?: 0

                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                            val pixelBuffer = ByteArray(width * height * 4)
                            outputBuffer.position(0)
                            outputBuffer.get(pixelBuffer, 0, pixelBuffer.size)
                            bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(pixelBuffer))

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
                // INFO_OUTPUT_BUFFERS_CHANGED / INFO_OUTPUT_FORMAT_CHANGED: no action needed.

                // Progress
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

            try { videoCodec.stop()    } catch (_: Exception) {}
            try { videoCodec.release() } catch (_: Exception) {}
            try { extractor.release()  } catch (_: Exception) {}

            onCompletion()
        }
    }

    /** Returns a snapshot of the extracted frame paths collected so far. */
    fun getExtractedFrames(): List<String> {
        frameLock.lock()
        try {
            return extractedFrames.toList()
        } finally {
            frameLock.unlock()
        }
    }

    /** Signals the extraction loop to stop at the next iteration. */
    fun cancel() {
        frameLock.lock()
        isRunning = false
        frameLock.unlock()
    }

    /** Returns the video duration in seconds. */
    fun getVideoDurationSeconds(): Double =
        ((videoFormat?.getLong(MediaFormat.KEY_DURATION) ?: 0L) / 1_000_000.0)
}
