# Video Upload Logging Fix Plan

## Problem Statement

The Flutter app uploads videos successfully, but **nothing logs on the Flutter side**. Users cannot see upload progress, processing status, or debug information in the Flutter logs.

## Root Cause Analysis

### Issue 1: Flutter `print()` Statements Don't Appear in Android Logcat

**Current State:**
- Android (Kotlin) side uses `android.util.Log.d()` and `android.util.Log.e()` → These appear in Android logcat
- Flutter (Dart) side uses `print()` → These do **NOT** appear in Android logcat by default

**Evidence:**
- [`MediaPickerService`](ai_fake_news_detector/lib/services/media_picker_service.dart) has 85+ `print()` statements
- [`MediaAnalysisChannel`](ai_fake_news_detector/lib/services/media_analysis_channel.dart) has **zero** logging
- [`ProcessingScreen`](ai_fake_news_detector/lib/pages/ProcessingScreen.dart) has **zero** logging
- [`MediaPickerPage`](ai_fake_news_detector/lib/pages/MediaPickerPage.dart) has **zero** logging

**Impact:**
- Flutter developers cannot see:
  - Permission check results
  - File selection events
  - Upload progress updates
  - Processing status changes
  - Error messages from the Flutter side

### Issue 2: Missing Method Channel Handlers for Video Frame Progress

**Current State:**
- [`MainActivity.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MainActivity.kt) sends:
  - `sendVideoFrameProgress()` → calls `onVideoFrameProgress`
  - `sendVideoFrameCancellation()` → calls `onVideoFrameCancellation`
- [`media_analysis_channel.dart`](ai_fake_news_detector/lib/services/media_analysis_channel.dart) handles:
  - ✅ `onAnalysisResult`
  - ✅ `onAnalysisError`
  - ✅ `onAnalysisCancelled`
  - ✅ `onAnalysisProgress`
  - ✅ `onVideoFrameResult`
  - ✅ `onVideoFrameError`
  - ❌ `onVideoFrameProgress` **MISSING**
  - ❌ `onVideoFrameCancellation` **MISSING**

**Impact:**
- Video frame extraction progress updates are sent from Android but **silently dropped** by Flutter
- Video frame processing cancellation events are sent from Android but **silently dropped** by Flutter
- The `ProcessingScreen` progress bar never updates during video frame extraction

### Issue 3: No Logging in Critical Flutter Components

**Current State:**
- [`MediaAnalysisChannel._handleMethodCall()`](ai_fake_news_detector/lib/services/media_analysis_channel.dart:51) receives method calls from Android but has **no logging**
- [`ProcessingScreen.initState()`](ai_fake_news_detector/lib/pages/ProcessingScreen.dart:46) registers listeners but has **no logging**
- [`ProcessingScreen._readArgs()`](ai_fake_news_detector/lib/pages/ProcessingScreen.dart:118) reads route arguments but has **no logging**

**Impact:**
- Impossible to debug whether:
  - Method channel calls are being received
  - Listeners are being registered correctly
  - Route arguments are being passed correctly
  - Progress events are being processed

## Solution Plan

### Fix 1: Replace `print()` with `debugPrint()` in Flutter

**Why:**
- `debugPrint()` outputs to Android logcat in debug mode
- `print()` only outputs to Dart console
- This is the standard Flutter approach for platform logging

**Files to Update:**
1. [`media_picker_service.dart`](ai_fake_news_detector/lib/services/media_picker_service.dart) - Replace all 85+ `print()` calls
2. [`fact_check_service.dart`](ai_fake_news_detector/lib/services/fact_check_service.dart) - Replace `print()` calls
3. [`auth_service.dart`](ai_fake_news_detector/lib/services/auth_service.dart) - Replace `print()` calls
4. [`auth_controller.dart`](ai_fake_news_detector/lib/services/auth_controller.dart) - Replace `print()` calls
5. [`notification_service.dart`](ai_fake_news_detector/lib/services/notification_service.dart) - Replace `print()` calls
6. [`LoginScreen.dart`](ai_fake_news_detector/lib/pages/LoginScreen.dart) - Replace `print()` calls
7. [`HomePage.dart`](ai_fake_news_detector/lib/pages/HomePage.dart) - Replace `print()` calls

**Implementation:**
```dart
// Before
print('MediaPickerService: Checking media permissions...');

// After
debugPrint('MediaPickerService: Checking media permissions...');
```

### Fix 2: Add Missing Method Channel Handlers

**File to Update:**
- [`media_analysis_channel.dart`](ai_fake_news_detector/lib/services/media_analysis_channel.dart)

**Changes:**
1. Add listener lists for video frame progress and cancellation:
```dart
static final List<void Function(Map<String, dynamic>)> _videoFrameProgressListeners = [];
static final List<void Function(Map<String, dynamic>)> _videoFrameCancellationListeners = [];
```

2. Add handlers in `_handleMethodCall()`:
```dart
case 'onVideoFrameProgress':
  final data = Map<String, dynamic>.from(call.arguments as Map);
  for (final cb in List.of(_videoFrameProgressListeners)) {
    cb(data);
  }
  break;

case 'onVideoFrameCancellation':
  final data = Map<String, dynamic>.from(call.arguments as Map);
  for (final cb in List.of(_videoFrameCancellationListeners)) {
    cb(data);
  }
  break;
```

3. Add subscription management methods:
```dart
static void addOnVideoFrameProgress(void Function(Map<String, dynamic>) cb) =>
    _videoFrameProgressListeners.add(cb);

static void removeOnVideoFrameProgress(void Function(Map<String, dynamic>) cb) =>
    _videoFrameProgressListeners.remove(cb);

static void addOnVideoFrameCancellation(void Function(Map<String, dynamic>) cb) =>
    _videoFrameCancellationListeners.add(cb);

static void removeOnVideoFrameCancellation(void Function(Map<String, dynamic>) cb) =>
    _videoFrameCancellationListeners.remove(cb);
```

### Fix 3: Add Logging to Critical Flutter Components

**Files to Update:**

1. **[`media_analysis_channel.dart`](ai_fake_news_detector/lib/services/media_analysis_channel.dart)**
   - Add logging in `_handleMethodCall()` for each method type
   - Add logging when listeners are added/removed

2. **[`ProcessingScreen.dart`](ai_fake_news_detector/lib/pages/ProcessingScreen.dart)**
   - Add logging in `initState()` when listeners are registered
   - Add logging in `_readArgs()` when route arguments are read
   - Add logging in progress stream listener

3. **[`MediaPickerPage.dart`](ai_fake_news_detector/lib/pages/MediaPickerPage.dart)**
   - Add logging in `_proceedWithFile()` when upload starts

**Example Implementation:**
```dart
// In media_analysis_channel.dart
static Future<void> _handleMethodCall(MethodCall call) async {
  debugPrint('MediaAnalysisChannel: Received method call: ${call.method}');
  
  switch (call.method) {
    case 'onAnalysisResult':
      final data = Map<String, dynamic>.from(call.arguments as Map);
      debugPrint('MediaAnalysisChannel: Analysis result received: $data');
      for (final cb in List.of(_resultListeners)) {
        cb(data);
      }
      break;
    // ... other cases
  }
}

// In ProcessingScreen.dart
@override
void initState() {
  super.initState();
  debugPrint('ProcessingScreen: initState called');
  
  _onResult = (resultData) {
    debugPrint('ProcessingScreen: Analysis result received: $resultData');
    // ... existing code
  };
  
  // ... register listeners
  debugPrint('ProcessingScreen: Listeners registered');
}

void _readArgs() {
  final args = ModalRoute.of(context)?.settings.arguments
      as Map<String, dynamic>?;
  debugPrint('ProcessingScreen: Route arguments: $args');
  
  if (args != null) {
    setState(() {
      _taskId = args['taskId'] as String?;
      _filePath = args['filePath'] as String?;
      _fileType = args['fileType'] as String?;
    });
    debugPrint('ProcessingScreen: TaskId=$_taskId, FilePath=$_filePath, FileType=$_fileType');
  }
}
```

### Fix 4: Update ProcessingScreen to Handle Video Frame Progress

**File to Update:**
- [`ProcessingScreen.dart`](ai_fake_news_detector/lib/pages/ProcessingScreen.dart)

**Changes:**
1. Add state variable for video frame progress:
```dart
double _videoFrameProgress = 0.0;
```

2. Register video frame progress listener in `initState()`:
```dart
_onVideoFrameProgress = (progressData) {
  if (mounted && !_isDisposed) {
    debugPrint('ProcessingScreen: Video frame progress: $progressData');
    setState(() {
      _videoFrameProgress = (progressData['progress'] as num?)?.toDouble() ?? 0.0;
      _frameCount = progressData['frameCount'] as int? ?? _frameCount;
    });
  }
};
MediaAnalysisChannel.addOnVideoFrameProgress(_onVideoFrameProgress);
```

3. Unregister in `dispose()`:
```dart
MediaAnalysisChannel.removeOnVideoFrameProgress(_onVideoFrameProgress);
```

4. Update `_buildProgressIndicator()` to show video frame progress:
```dart
if (_status == 'extracting_frames') {
  return Column(
    children: [
      LinearProgressIndicator(
        value: _videoFrameProgress,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(GlobalColors.mainColor),
        minHeight: 8,
      ),
      const SizedBox(height: 8),
      Text(
        'Extracting frames… ${(_videoFrameProgress * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: GlobalColors.mainColor,
        ),
      ),
      if (_frameCount > 0) ...[
        const SizedBox(height: 8),
        Text(
          '$_frameCount frames extracted',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    ],
  );
}
```

## Testing Plan

### Test 1: Verify Flutter Logs Appear in Logcat
1. Run app in debug mode
2. Open Android logcat with filter: `flutter`
3. Pick a video from gallery
4. Verify logs appear:
   - `MediaPickerService: Checking media permissions...`
   - `MediaPickerService: Picking video from gallery...`
   - `MediaPickerService: Video selected: /path/to/video.mp4`
   - `MediaPickerService: Video file size: XXXXX bytes`
   - `MediaPickerService: Video validation successful`

### Test 2: Verify Video Frame Progress Updates
1. Run app in debug mode
2. Open Android logcat with filter: `flutter`
3. Pick a video (10-30 seconds)
4. Verify logs appear:
   - `ProcessingScreen: initState called`
   - `ProcessingScreen: Listeners registered`
   - `ProcessingScreen: Route arguments: {taskId: XXX, filePath: XXX, fileType: video}`
   - `ProcessingScreen: Video frame progress: {taskId: XXX, progress: 0.1, frameCount: 3}`
   - `ProcessingScreen: Video frame progress: {taskId: XXX, progress: 0.2, frameCount: 6}`
   - ... (continues until completion)

### Test 3: Verify Progress Bar Updates
1. Run app on physical device
2. Pick a video (30-60 seconds)
3. Observe ProcessingScreen:
   - Progress bar should show frame extraction progress (0-100%)
   - Frame count should update as frames are extracted
   - Status should change from "Extracting frames…" to "Uploading frames…" to "Processing…"

## Expected Outcomes

After implementing these fixes:

1. **Flutter logs will appear in Android logcat** - Developers can debug the entire upload flow
2. **Video frame progress will be visible** - Users see real-time progress during frame extraction
3. **Method channel communication will be traceable** - Easy to debug Android ↔ Flutter communication
4. **Progress bar will update smoothly** - Better user experience during video processing

## Files Modified

| File | Changes |
|------|---------|
| `lib/services/media_picker_service.dart` | Replace 85+ `print()` with `debugPrint()` |
| `lib/services/media_analysis_channel.dart` | Add missing handlers, add logging |
| `lib/pages/ProcessingScreen.dart` | Add video frame progress handling, add logging |
| `lib/pages/MediaPickerPage.dart` | Add logging |
| `lib/services/fact_check_service.dart` | Replace `print()` with `debugPrint()` |
| `lib/services/auth_service.dart` | Replace `print()` with `debugPrint()` |
| `lib/services/auth_controller.dart` | Replace `print()` with `debugPrint()` |
| `lib/services/notification_service.dart` | Replace `print()` with `debugPrint()` |
| `lib/pages/LoginScreen.dart` | Replace `print()` with `debugPrint()` |
| `lib/pages/HomePage.dart` | Replace `print()` with `debugPrint()` |

## Priority

**HIGH** - This fix is critical for:
- Debugging upload issues
- Providing user feedback during video processing
- Maintaining code quality and observability
