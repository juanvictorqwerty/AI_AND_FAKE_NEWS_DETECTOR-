# Fix Plan: BufferUnderflowException in Frame Extraction

## Problem Analysis

After fixing the @UiThread crash, a new error appeared:

```
E/FrameExtractor(11007): Error during frame extraction: null
E/FrameExtractor(11007): java.nio.BufferUnderflowException
E/FrameExtractor(11007):        at java.nio.DirectByteBuffer.get(DirectByteBuffer.java:239)
E/FrameExtractor(11007):        at com.example.ai_fake_news_detector.FrameExtractor.extractFrames(FrameExtractor.kt:201)
```

### Root Cause

The code at line 201 of [`FrameExtractor.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/FrameExtractor.kt:201) is trying to read raw pixel data from the output buffer:

```kotlin
val pixelBuffer = ByteArray(width * height * 4)
outputBuffer.position(0)
outputBuffer.get(pixelBuffer, 0, pixelBuffer.size)  // Line 201 - CRASH HERE
```

**The problem:** MediaCodec outputs video frames in YUV format (typically YUV420 semi-planar), NOT in ARGB_8888 format. The output buffer size is much smaller than `width * height * 4` bytes, causing the BufferUnderflowException.

### Why This Happens

- YUV420 semi-planar uses 1.5 bytes per pixel (12 bits per pixel)
- ARGB_8888 uses 4 bytes per pixel (32 bits per pixel)
- For a 360x640 video:
  - YUV420 buffer size: 360 × 640 × 1.5 = 345,600 bytes
  - ARGB_8888 buffer size: 360 × 640 × 4 = 921,600 bytes
- The code tries to read 921,600 bytes from a 345,600 byte buffer → BufferUnderflowException

## Solution Strategy

Replace the incorrect raw buffer reading with proper YUV to RGB conversion. The best approach is to use Android's built-in YuvImage class to convert YUV to JPEG, then decode to Bitmap.

## Implementation Steps

### Step 1: Update FrameExtractor.kt

Replace the problematic buffer reading code (lines 198-202) with proper YUV to RGB conversion:

**Current problematic code:**
```kotlin
val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
val pixelBuffer = ByteArray(width * height * 4)
outputBuffer.position(0)
outputBuffer.get(pixelBuffer, 0, pixelBuffer.size)
bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(pixelBuffer))
```

**New code using YuvImage:**
```kotlin
// Get the actual color format from the output buffer
val colorFormat = videoFormat?.getInteger(MediaFormat.KEY_COLOR_FORMAT) ?: 0

// Convert YUV to JPEG using YuvImage
val yuvImage = YuvImage(
    outputBuffer.array(),
    colorFormat,
    width,
    height,
    null
)

val jpegStream = ByteArrayOutputStream()
yuvImage.compressToJpeg(Rect(0, 0, width, height), 100, jpegStream)
val jpegData = jpegStream.toByteArray()

val bitmap = BitmapFactory.decodeByteArray(jpegData, 0, jpegData.size)
```

### Step 2: Add Required Imports

Add imports for:
- `android.graphics.YuvImage`
- `android.graphics.Rect`
- `android.graphics.BitmapFactory`
- `java.io.ByteArrayOutputStream`

### Step 3: Handle Buffer Position

Ensure the output buffer position is reset before reading:
```kotlin
outputBuffer.position(0)
```

## Files to Modify

1. **ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/FrameExtractor.kt**
   - Add imports for YuvImage, Rect, BitmapFactory, ByteArrayOutputStream
   - Replace lines 198-202 with proper YUV to RGB conversion

## Testing Plan

1. Build and run the app
2. Select a video for processing
3. Verify frame extraction completes without BufferUnderflowException
4. Verify extracted frames are valid PNG images
5. Verify progress updates work correctly

## Expected Outcome

- No more BufferUnderflowException crashes
- Frame extraction completes successfully
- Extracted frames are valid images
- App remains stable during video processing

## Risk Assessment

**Low Risk:** The change uses Android's built-in YuvImage class which is specifically designed for this purpose:
- YuvImage is part of Android SDK (API 8+)
- It handles all YUV format variations automatically
- The conversion is efficient and well-tested
- No external dependencies required

## Alternative Approaches Considered

1. **Manual YUV to RGB conversion** - Rejected because it's complex and error-prone
2. **Using RenderScript** - Rejected because it's deprecated and more complex
3. **Using a Surface with ImageReader** - Rejected because it requires significant refactoring
4. **Using MediaMetadataRetriever** - Rejected because it doesn't provide the same level of control

## Dependencies

- Android YuvImage API (API 8+, always available)
- Android BitmapFactory API (always available)
- No external libraries required
