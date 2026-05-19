# Kotlin Refactoring Plan: Image Analysis Services with Background Processing

## Overview

This document outlines the plan to refactor image analysis services from Dart (Flutter) to Kotlin (Android native) with background processing capabilities. The goal is to maintain the same app functionality while enabling background processing for better user experience.

## Current Architecture

### Dart Side (Flutter)
- **MediaApiService**: Handles API calls (upload, polling, results)
- **MediaUploadController**: Manages upload state and coordinates with API service
- **MediaPickerService**: Handles file picking from gallery

### Kotlin Side (Android)
- **MainActivity**: Main activity with method channel setup
- **NotificationForegroundService**: Handles foreground notifications
- **FactCheckApiService**: Handles fact-checking API calls
- **ConfigManager**: Manages configuration
- **BootReceiver**: Handles boot events

## Proposed Architecture

### Kotlin Services (New)
1. **MediaAnalysisService**: Background service for image analysis
2. **MediaUploadService**: Handles API calls in background
3. **MediaProcessingWorker**: WorkManager worker for background tasks

### Dart Side (Updated)
1. **MediaApiService**: Updated to use Kotlin services via platform channels
2. **MediaUploadController**: Updated to work with background processing

## Implementation Plan

### Phase 1: Create Kotlin Background Services

#### 1.1 MediaAnalysisService.kt
```kotlin
class MediaAnalysisService : Service() {
    // Handles background image analysis
    // Uses WorkManager for background processing
    // Communicates with Flutter via MethodChannel
    // Manages upload and polling in background
}
```

**Key Features:**
- Background file upload
- Background polling for results
- Progress notifications
- Error handling and retry logic
- Battery optimization

#### 1.2 MediaUploadService.kt
```kotlin
class MediaUploadService {
    // Handles API calls
    // File upload with multipart requests
    // Result polling
    // Retry mechanism
    // Timeout handling
}
```

**Key Features:**
- HTTP client for API calls
- Multipart file upload
- JSON parsing
- Error handling
- Retry logic

#### 1.3 MediaProcessingWorker.kt
```kotlin
class MediaProcessingWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    // WorkManager worker for background processing
    // Handles long-running tasks
    // Survives app termination
    // Battery efficient
}
```

### Phase 2: Update Android Manifest

#### 2.1 Add Required Permissions
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

#### 2.2 Register Services
```xml
<service
    android:name=".MediaAnalysisService"
    android:foregroundServiceType="dataSync"
    android:exported="false" />

<provider
    android:name="androidx.startup.InitializationProvider"
    android:authorities="${applicationId}.androidx-startup"
    android:exported="false"
    tools:node="merge">
    <meta-data
        android:name="androidx.work.WorkManagerInitializer"
        android:value="androidx.startup"
        tools:node="remove" />
</provider>
```

### Phase 3: Create Platform Channels

#### 3.1 Method Channel Setup
```kotlin
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ai_fake_news_detector/media_analysis"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startAnalysis" -> startAnalysis(call, result)
                "getAnalysisStatus" -> getAnalysisStatus(call, result)
                "cancelAnalysis" -> cancelAnalysis(call, result)
                else -> result.notImplemented()
            }
        }
    }
}
```

#### 3.2 Dart Side Platform Channel
```dart
class MediaAnalysisChannel {
    static const MethodChannel _channel = MethodChannel('com.example.ai_fake_news_detector/media_analysis');
    
    static Future<String> startAnalysis(String filePath, String fileType) async {
        final result = await _channel.invokeMethod('startAnalysis', {
            'filePath': filePath,
            'fileType': fileType,
        });
        return result;
    }
}
```

### Phase 4: Update Dart Services

#### 4.1 Update MediaApiService
- Keep existing API methods for compatibility
- Add methods to use Kotlin services
- Implement fallback to Dart if Kotlin fails

#### 4.2 Update MediaUploadController
- Add support for background processing
- Update state management for background tasks
- Add notification handling

### Phase 5: Testing and Optimization

#### 5.1 Test Background Processing
- Test upload in background
- Test polling in background
- Test notification updates
- Test error handling

#### 5.2 Battery Optimization
- Use WorkManager for battery efficiency
- Implement proper wake locks
- Optimize polling intervals

## File Structure

```
ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/
├── MainActivity.kt (updated)
├── MediaAnalysisService.kt (new)
├── MediaUploadService.kt (new)
├── MediaProcessingWorker.kt (new)
├── NotificationForegroundService.kt (existing)
├── FactCheckApiService.kt (existing)
├── ConfigManager.kt (existing)
└── BootReceiver.kt (existing)
```

## Benefits

1. **Background Processing**: Upload and analysis continue even when app is minimized
2. **Better UX**: Users can continue using the app while processing
3. **Battery Efficiency**: WorkManager optimizes background tasks
4. **Reliability**: Background tasks survive app termination
5. **Notifications**: Users get updates on processing status

## Migration Strategy

1. **Gradual Migration**: Keep Dart services as fallback
2. **Feature Flags**: Enable Kotlin services gradually
3. **Testing**: Comprehensive testing before full rollout
4. **Rollback**: Easy rollback if issues arise

## Timeline

- Phase 1: 2-3 days (Kotlin services)
- Phase 2: 1 day (Android manifest)
- Phase 3: 1-2 days (Platform channels)
- Phase 4: 2-3 days (Dart updates)
- Phase 5: 2-3 days (Testing)

Total: 8-12 days

## Success Criteria

1. Background upload works correctly
2. Background polling works correctly
3. Notifications are displayed properly
4. Battery usage is optimized
5. App functionality remains the same
6. Error handling is robust
7. Performance is maintained or improved
