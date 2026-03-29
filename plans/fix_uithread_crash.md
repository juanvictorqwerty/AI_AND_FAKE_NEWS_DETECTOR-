# Fix Plan: @UiThread Violation in Video Frame Processing

## Problem Analysis

The app crashes with:
```
java.lang.RuntimeException: Methods marked with @UiThread must be executed on the main thread. Current thread: DefaultDispatcher-worker-1
```

### Root Cause
Flutter's `MethodChannel.invokeMethod()` must be called on the main UI thread, but the code is calling it from background threads (Dispatchers.IO) in multiple places:

1. **VideoFrameProcessingService.kt:240** - `onProgressUpdate` callback
2. **VideoFrameProcessingService.kt:265** - `onCompletion` callback  
3. **VideoFrameProcessingService.kt:279** - `serviceScope.launch` block
4. **VideoFrameProcessingService.kt:290** - `serviceScope.launch` block

### Stack Trace Flow
```
FrameExtractor.kt:236 (onProgressUpdate callback)
  ↓
VideoFrameProcessingService.kt:240 (MainActivity.sendVideoFrameProgress)
  ↓
MainActivity.kt:111 (videoFrameProcessingChannel?.invokeMethod)
  ↓
FlutterJNI.dispatchPlatformMessage (requires @UiThread)
```

## Solution Strategy

Modify the `MainActivity` companion object methods to automatically dispatch `MethodChannel.invokeMethod()` calls to the main thread using `Handler(Looper.getMainLooper())`. This encapsulates thread management and makes the API safe for callers from any thread.

## Implementation Steps

### Step 1: Update MainActivity.kt
Add a Handler for main thread dispatching and modify all send methods:

**Changes:**
- Add `private val mainHandler = Handler(Looper.getMainLooper())` to companion object
- Modify `sendAnalysisResult()` to dispatch to main thread
- Modify `sendAnalysisError()` to dispatch to main thread
- Modify `sendVideoFrameProgress()` to dispatch to main thread
- Modify `sendVideoFrameError()` to dispatch to main thread
- Modify `sendVideoFrameCancellation()` to dispatch to main thread

**Pattern for each method:**
```kotlin
fun sendVideoFrameProgress(progressData: Map<String, Any>): Boolean {
    val success = videoFrameProcessingChannel != null
    if (success) {
        mainHandler.post {
            videoFrameProcessingChannel?.invokeMethod("onVideoFrameProgress", progressData)
        }
    }
    return success
}
```

### Step 2: Verify No Other Issues
Check if there are other places in the codebase that might have similar threading issues with MethodChannel calls.

## Files to Modify

1. **ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MainActivity.kt**
   - Add Handler import
   - Add mainHandler to companion object
   - Update all send methods to use mainHandler.post { }

## Testing Plan

1. Build and run the app
2. Select a video for processing
3. Verify frame extraction progress updates are sent without crashes
4. Verify error handling works correctly
5. Verify completion notifications work correctly

## Expected Outcome

- No more @UiThread crashes
- Frame extraction progress updates work correctly
- Error messages are properly delivered to Flutter
- App remains stable during video processing

## Risk Assessment

**Low Risk:** The change is minimal and follows Android best practices:
- Using `Handler(Looper.getMainLooper())` is the standard way to post to main thread
- The change is encapsulated in MainActivity, so no other code needs modification
- Return values remain the same (Boolean indicating if channel exists)
- No changes to the Flutter side of the code

## Alternative Approaches Considered

1. **Modify callers to use `withContext(Dispatchers.Main)`** - Rejected because it requires changes in multiple places and is error-prone
2. **Use `runOnUiThread`** - Rejected because we don't have Activity context in companion object
3. **Use `CoroutineScope(Dispatchers.Main).launch`** - Rejected because it's more complex and less efficient than Handler

## Dependencies

- Android Handler API (already available)
- Looper.getMainLooper() (API 1+, always available)
