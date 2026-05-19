# Video Frame Processing Implementation

## Overview

This implementation provides a Kotlin (Android) background service that processes videos into frames at exactly 1 FPS. The service runs in the background using a Foreground Service and communicates with Flutter via Platform Channels.

## Architecture

### Components

1. **FrameExtractor** - Core frame extraction logic using MediaExtractor and MediaCodec
2. **VideoFrameProcessingService** - Foreground service that orchestrates the extraction process
3. **MainActivity** - Platform channel integration for Flutter communication

### Design Principles

- **Modular Design**: Each component has a single responsibility
- **Reusable**: Components can be reused for future KMP integration
- **Background Execution**: Uses Foreground Service for reliable background processing
- **Progress Updates**: Provides real-time progress updates to Flutter
- **Error Handling**: Comprehensive error handling for various failure scenarios

## Implementation Details

### FrameExtractor

**Location**: `ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/FrameExtractor.kt`

**Key Features**:
- Uses Android-native MediaExtractor and MediaCodec for frame extraction
- Extracts frames at exactly 1 FPS (one frame per second)
- Validates video duration (max 45 seconds)
- Saves frames as PNG files with maximum quality
- Preserves original video resolution
- Thread-safe with ReentrantLock for concurrent access
- Proper resource cleanup in finally blocks

**Frame Extraction Process**:
1. Initialize MediaExtractor and find video track
2. Configure MediaCodec decoder for H.264
3. For each second from 0 to duration:
   - Extract frame at timestamp t * 1000 ms
   - Save as PNG in app-specific storage
   - Log extracted timestamp
   - Update progress

**Memory Optimization**:
- Recycles Bitmaps immediately after saving
- Releases MediaCodec buffers promptly
- Uses try-finally for guaranteed resource cleanup

### VideoFrameProcessingService

**Location**: `ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/VideoFrameProcessingService.kt`

**Key Features**:
- Foreground service for reliable background execution
- Shows notification with progress updates
- Handles multiple concurrent tasks
- Thread-safe task state management
- Proper lifecycle management

**Service Methods**:
- `startVideoFrameProcessing(context, videoPath, taskId)` - Start processing
- `cancelVideoFrameProcessing(context, taskId)` - Cancel processing
- `getProcessingProgress(taskId)` - Get current progress
- `getExtractedFrames(taskId)` - Get list of extracted frames

**Progress Updates**:
- Updates notification with progress percentage
- Sends progress to Flutter via MainActivity
- Tracks extracted frames count

### MainActivity Integration

**Location**: `ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MainActivity.kt`

**Platform Channel**: `com.example.ai_fake_news_detector/video_frame_processing`

**Flutter Methods**:
- `startVideoProcessing(videoPath, taskId)` - Start video processing
- `cancelVideoProcessing(taskId)` - Cancel processing
- `getProcessingProgress(taskId)` - Get current progress
- `getExtractedFrames(taskId)` - Get extracted frame paths

**Callbacks to Flutter**:
- `onVideoFrameResult` - Processing completed
- `onVideoFrameError` - Processing failed
- `onVideoFrameProgress` - Progress update
- `onVideoFrameCancellation` - Processing cancelled

## Error Handling

### Video Validation
- **Duration Check**: Videos longer than 45 seconds are rejected
- **Format Validation**: Validates that video can be read by MediaExtractor
- **Track Detection**: Ensures video track exists

### Runtime Errors
- **Invalid Files**: Catches and reports corrupt video files
- **Permission Issues**: Handles storage permission errors
- **Storage Limitations**: Checks available storage before processing
- **Memory Errors**: Proper resource cleanup to prevent OOM

### Error Reporting
- All errors are reported to Flutter via `onVideoFrameError`
- Error messages include detailed information for debugging
- Service stops gracefully on error

## Storage Management

### Output Location
- Uses app-specific storage: `getExternalCacheDir()` or `cacheDir`
- Creates subdirectory: `video_frames_{taskId}`
- No special permissions required for Android 10+

### File Naming
- Frames saved as: `frame_{second}.png`
- Example: `frame_0.png`, `frame_1.png`, etc.

### Cleanup
- Frames are stored in cache directory
- Can be cleared by system when storage is low
- Manual cleanup can be implemented if needed

## Performance Considerations

### Memory Usage
- Bitmaps are recycled immediately after saving
- MediaCodec buffers are released promptly
- No accumulation of frames in memory

### CPU Usage
- Uses hardware-accelerated MediaCodec
- Processes frames sequentially to avoid overload
- Proper thread management with coroutines

### Battery Usage
- Foreground service with low-priority notification
- Efficient resource usage
- Proper cleanup to prevent battery drain

## Flutter Integration

### Dart Code Example

```dart
import 'package:flutter/services.dart';

class VideoFrameProcessing {
  static const MethodChannel _channel = MethodChannel(
    'com.example.ai_fake_news_detector/video_frame_processing'
  );

  static Future<void> startProcessing(String videoPath, String taskId) async {
    await _channel.invokeMethod('startVideoProcessing', {
      'videoPath': videoPath,
      'taskId': taskId,
    });
  }

  static Future<void> cancelProcessing(String taskId) async {
    await _channel.invokeMethod('cancelVideoProcessing', {
      'taskId': taskId,
    });
  }

  static Future<double> getProgress(String taskId) async {
    final result = await _channel.invokeMethod('getProcessingProgress', {
      'taskId': taskId,
    });
    return result['progress'] as double;
  }

  static Future<List<String>> getExtractedFrames(String taskId) async {
    final result = await _channel.invokeMethod('getExtractedFrames', {
      'taskId': taskId,
    });
    return List<String>.from(result['framePaths']);
  }
}
```

### Callback Handling

```dart
_channel.setMethodCallHandler((call) async {
  switch (call.method) {
    case 'onVideoFrameResult':
      // Handle completion
      final taskId = call.arguments['taskId'];
      final frameCount = call.arguments['frameCount'];
      break;
    case 'onVideoFrameError':
      // Handle error
      final taskId = call.arguments['taskId'];
      final error = call.arguments['error'];
      break;
    case 'onVideoFrameProgress':
      // Handle progress update
      final taskId = call.arguments['taskId'];
      final progress = call.arguments['progress'];
      break;
    case 'onVideoFrameCancellation':
      // Handle cancellation
      final taskId = call.arguments['taskId'];
      break;
  }
});
```

## Testing

### Manual Testing
1. Test with valid video files (≤45 seconds)
2. Test with video files >45 seconds (should reject)
3. Test with corrupt video files
4. Test cancellation during processing
5. Test app minimization during processing
6. Test with various video formats (MP4, MOV, etc.)

### Automated Testing
- Unit tests for FrameExtractor validation logic
- Integration tests for service lifecycle
- Platform channel communication tests

## Future Enhancements

### Potential Improvements
1. **Batch Processing**: Process multiple videos in sequence
2. **Frame Selection**: Allow custom frame selection (e.g., every 2 seconds)
3. **Format Options**: Support JPEG with configurable quality
4. **Resolution Options**: Allow downscaling for performance
5. **Progress Persistence**: Save progress for resumable processing

### KMP Integration
- FrameExtractor logic can be extracted to shared Kotlin module
- Service orchestration remains Android-specific
- Platform channel interface can be shared

## Dependencies

### Android Dependencies
- `androidx.work:work-runtime-ktx` - WorkManager (if needed)
- `kotlinx-coroutines-android` - Coroutines support
- `androidx.core:core-ktx` - Core Kotlin extensions

### Permissions
- `FOREGROUND_SERVICE` - Required for foreground service
- `FOREGROUND_SERVICE_DATA_SYNC` - Required for data sync foreground service
- `READ_EXTERNAL_STORAGE` - For reading video files (Android <13)
- `READ_MEDIA_VIDEO` - For reading video files (Android 13+)

## Conclusion

This implementation provides a robust, efficient, and maintainable solution for video frame extraction on Android. It meets all requirements including:
- Background execution with progress updates
- Exact 1 FPS frame extraction
- Error handling for various scenarios
- Flutter integration via Platform Channels
- Memory optimization and resource management
- Android 10+ compatibility with scoped storage