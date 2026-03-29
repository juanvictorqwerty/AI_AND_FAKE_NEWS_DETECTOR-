# Video Frame Upload Implementation Plan

## Overview
Update the app to handle video uploads by extracting frames and sending them to the `/upload/video` FastAPI endpoint, instead of uploading the raw video file.

## Current Architecture Analysis

### Existing Components
1. **FrameExtractor.kt** - Already extracts frames at 1 FPS with max 45 seconds (45 frames)
2. **VideoFrameProcessingService.kt** - Foreground service for frame extraction
3. **MediaUploadService.kt** - Handles file uploads to `/upload` endpoint
4. **MediaAnalysisService.kt** - Orchestrates upload and polling flow
5. **Flutter UI** - MediaPickerPage, ProcessingScreen, MediaResultPage

### Current Flow
```
User picks video → MediaAnalysisService.uploadFile() → POST /upload → Poll /results/{file_id}
```

### New Flow
```
User picks video → Extract frames (1 FPS, max 45) → Upload frames to POST /upload/video → Display aggregated result
```

## Implementation Steps

### Phase 1: Kotlin Backend Changes

#### 1.1 Update MediaUploadService.kt
Add new method `uploadFramesToVideoEndpoint()`:
- Accept list of frame file paths
- Create multipart/form-data request with multiple image files
- Send to POST /upload/video endpoint
- Handle response with new format (includes frames list, label_distribution, etc.)
- Validate frame count (max 60)
- Support image formats: PNG, JPG, JPEG, BMP, WEBP

**Key Changes:**
```kotlin
suspend fun uploadFramesToVideoEndpoint(framePaths: List<String>): VideoUploadResponse {
    // Validate frame count
    if (framePaths.size > 60) {
        throw Exception("Too many frames: ${framePaths.size}. Maximum is 60.")
    }
    
    // Build multipart request with all frames
    val requestBody = MultipartBody.Builder()
        .setType(MultipartBody.FORM)
    
    framePaths.forEachIndexed { index, framePath ->
        val file = File(framePath)
        requestBody.addFormDataPart(
            "files",  // or "images" depending on API
            file.name,
            file.asRequestBody(getMimeType(framePath).toMediaType())
        )
    }
    
    // POST to /upload/video
    val request = Request.Builder()
        .url("$baseUrl/upload/video")
        .post(requestBody.build())
        .build()
    
    // Parse response
    return VideoUploadResponse.fromJson(jsonResponse)
}
```

#### 1.2 Create VideoUploadResponse Model
New data class to handle `/upload/video` response:
```kotlin
data class VideoUploadResponse(
    val status: String,
    val prediction: String,
    val confidence: Double,
    val frameCount: Int,
    val validFrameCount: Int,
    val aggregatedScore: Double,
    val frames: List<FrameResult>,
    val labelDistribution: Map<String, LabelStats>,
    val totalProcessingTime: Double,
    val error: String?
)

data class FrameResult(
    val filename: String,
    val prediction: String,
    val confidence: Double,
    val url: String?  // If FastAPI serves images
)

data class LabelStats(
    val count: Int,
    val totalConfidence: Double,
    val avgConfidence: Double
)
```

#### 1.3 Update VideoFrameProcessingService.kt
Modify to upload frames after extraction:
- After frame extraction completes, call `uploadFramesToVideoEndpoint()`
- Send progress updates during upload
- Handle upload errors
- Clean up temporary frame files after upload

**Key Changes:**
```kotlin
// In onCompletion callback:
onCompletion = {
    // Get extracted frames
    val framePaths = activeTasks[taskId]?.extractedFrames?.toList() ?: emptyList()
    
    // Upload frames to /upload/video
    serviceScope.launch {
        try {
            sendProgressToFlutter(taskId, "uploading_frames", 0.0)
            
            val uploadResponse = uploadService.uploadFramesToVideoEndpoint(framePaths)
            
            sendProgressToFlutter(taskId, "processing", 0.5)
            
            // Send result to Flutter
            sendVideoFrameResultToFlutter(taskId, uploadResponse)
            
            // Clean up frames
            framePaths.forEach { File(it).delete() }
            
        } catch (e: Exception) {
            sendVideoFrameErrorToFlutter(taskId, e.message ?: "Upload failed")
        }
    }
}
```

#### 1.4 Update MediaAnalysisService.kt
Modify `performAnalysis()` to handle video differently:
- If fileType is "video", start frame extraction instead of direct upload
- Use VideoFrameProcessingService for frame extraction and upload
- Handle the new response format

**Key Changes:**
```kotlin
private suspend fun performAnalysis(filePath: String, fileType: String, taskId: String) {
    if (fileType == "video") {
        // Video: extract frames and upload to /upload/video
        VideoFrameProcessingService.startVideoFrameProcessing(
            context = this,
            videoPath = filePath,
            taskId = taskId
        )
        // Service will handle upload and send results via MainActivity
    } else {
        // Image: use existing flow
        // ... existing code ...
    }
}
```

#### 1.5 Update MainActivity.kt
Add new method channel handlers for video frame processing:
- `sendVideoFrameResultToFlutter()` - Send aggregated result
- `sendVideoFrameErrorToFlutter()` - Send error
- `sendVideoFrameProgressToFlutter()` - Send progress updates

### Phase 2: Flutter Frontend Changes

#### 2.1 Create VideoFrameResult Model
New model for `/upload/video` response:
```dart
class VideoFrameResult {
  final String status;
  final String prediction;
  final double confidence;
  final int frameCount;
  final int validFrameCount;
  final double aggregatedScore;
  final List<FramePrediction> frames;
  final Map<String, LabelStats> labelDistribution;
  final double totalProcessingTime;
  final String? error;
  
  // ... fromJson, toJson methods
}

class FramePrediction {
  final String filename;
  final String prediction;
  final double confidence;
  final String? url;
  
  // ... fromJson, toJson methods
}

class LabelStats {
  final int count;
  final double totalConfidence;
  final double avgConfidence;
  
  // ... fromJson, toJson methods
}
```

#### 2.2 Update MediaAnalysisChannel
Add support for video frame processing events:
- `onVideoFrameResult` - Receive aggregated result
- `onVideoFrameError` - Receive error
- `onVideoFrameProgress` - Receive progress updates

**Key Changes:**
```dart
static final List<void Function(Map<String, dynamic>)> _videoFrameResultListeners = [];
static final List<void Function(Map<String, dynamic>)> _videoFrameErrorListeners = [];

static void addOnVideoFrameResult(void Function(Map<String, dynamic>) cb) =>
    _videoFrameResultListeners.add(cb);

static void removeOnVideoFrameResult(void Function(Map<String, dynamic>) cb) =>
    _videoFrameResultListeners.remove(cb);

// In _handleMethodCall:
case 'onVideoFrameResult':
    final data = Map<String, dynamic>.from(call.arguments as Map);
    for (final cb in List.of(_videoFrameResultListeners)) {
        cb(data);
    }
    break;
```

#### 2.3 Update ProcessingScreen
Show frame extraction and upload progress:
- Display "Extracting frames..." during extraction
- Display "Uploading frames..." during upload
- Show frame count progress (e.g., "Uploading frame 15/45")
- Handle video-specific progress events

**Key Changes:**
```dart
// Add video frame processing listeners
MediaAnalysisChannel.addOnVideoFrameResult(_onVideoFrameResult);
MediaAnalysisChannel.addOnVideoFrameError(_onVideoFrameError);

// Update progress UI for video
if (_fileType == 'video') {
    if (_status == 'extracting_frames') {
        return Column(
            children: [
                CircularProgressIndicator(),
                Text('Extracting frames...'),
                Text('$_frameCount frames extracted'),
            ],
        );
    }
    if (_status == 'uploading_frames') {
        return Column(
            children: [
                LinearProgressIndicator(value: _progress),
                Text('Uploading frames... ${(_progress * 100).toStringAsFixed(0)}%'),
            ],
        );
    }
}
```

#### 2.4 Update MediaResultPage
Display aggregated result and per-frame predictions:
- Show aggregated score prominently
- Display prediction (AI/Human) with confidence
- Optionally show per-frame predictions in expandable list
- Show label distribution chart
- Display processing time

**Key Changes:**
```dart
Widget _buildVideoFrameResult() {
    final result = _videoFrameResult;
    if (result == null) return SizedBox.shrink();
    
    return Column(
        children: [
            // Aggregated result card
            _buildAggregatedResultCard(result),
            
            // Label distribution
            _buildLabelDistribution(result.labelDistribution),
            
            // Per-frame predictions (expandable)
            ExpansionTile(
                title: Text('Per-Frame Predictions (${result.frames.length} frames)'),
                children: result.frames.map((frame) => 
                    _buildFramePredictionTile(frame)
                ).toList(),
            ),
        ],
    );
}

Widget _buildAggregatedResultCard(VideoFrameResult result) {
    return Card(
        child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
                children: [
                    Text(
                        result.prediction.toUpperCase(),
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: result.prediction == 'ai' ? Colors.red : Colors.green,
                        ),
                    ),
                    Text(
                        'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 18),
                    ),
                    Text(
                        'Aggregated Score: ${(result.aggregatedScore * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    Text(
                        '${result.validFrameCount}/${result.frameCount} valid frames',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                ],
            ),
        ),
    );
}
```

#### 2.5 Update AnalysisResult Model
Extend to support video frame results:
```dart
class AnalysisResult {
  // ... existing fields ...
  
  // New fields for video
  final int? frameCount;
  final int? validFrameCount;
  final double? aggregatedScore;
  final List<FramePrediction>? frames;
  final Map<String, LabelStats>? labelDistribution;
  final double? totalProcessingTime;
  
  // Helper to check if this is a video result
  bool get isVideoResult => frameCount != null;
}
```

### Phase 3: Error Handling

#### 3.1 Frame Count Validation
- Check if frame count > 60 before upload
- Show user-friendly error message
- Suggest trimming video or reducing duration

#### 3.2 Upload Failures
- Retry mechanism (already exists in MediaUploadService)
- Show error message with retry option
- Clean up temporary frames on failure

#### 3.3 Server Errors
- Parse error response from /upload/video
- Display meaningful error messages
- Handle network timeouts

### Phase 4: UI/UX Improvements

#### 4.1 Progress Indicators
- Frame extraction: Show frame count and percentage
- Frame upload: Show upload progress per frame
- Processing: Show "Analyzing frames..." message

#### 4.2 Result Display
- Prominent aggregated score display
- Color-coded prediction (red for AI, green for Human)
- Expandable per-frame predictions list
- Label distribution visualization

#### 4.3 Frame Preview
- Optionally show extracted frames in grid
- Allow user to tap frame to see prediction
- Display frame filename and confidence

## File Changes Summary

### Kotlin Files to Modify
1. `MediaUploadService.kt` - Add `uploadFramesToVideoEndpoint()` method
2. `VideoFrameProcessingService.kt` - Add upload logic after extraction
3. `MediaAnalysisService.kt` - Handle video uploads differently
4. `MainActivity.kt` - Add video frame result handlers
5. New: `VideoUploadResponse.kt` - Response model

### Flutter Files to Modify
1. `lib/models/analysis_result.dart` - Extend for video results
2. New: `lib/models/video_frame_result.dart` - Video-specific model
3. `lib/services/media_analysis_channel.dart` - Add video frame handlers
4. `lib/pages/ProcessingScreen.dart` - Show video-specific progress
5. `lib/pages/MediaResultPage.dart` - Display video frame results

## Testing Checklist

- [ ] Extract frames from 10-second video (10 frames)
- [ ] Extract frames from 45-second video (45 frames)
- [ ] Extract frames from 50-second video (should fail - too long)
- [ ] Upload 45 frames to /upload/video
- [ ] Upload 61 frames (should fail - too many)
- [ ] Handle upload failure (network error)
- [ ] Handle server error response
- [ ] Display aggregated result correctly
- [ ] Display per-frame predictions
- [ ] Show progress during extraction
- [ ] Show progress during upload
- [ ] Clean up temporary frames after upload
- [ ] Handle video with no valid frames
- [ ] Test with different video formats (MP4, MOV, AVI)

## API Endpoint Details

### POST /upload/video
**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Body: Multiple image files (PNG, JPG, JPEG, BMP, WEBP)
- Max files: 60

**Response:**
```json
{
  "status": "string",
  "prediction": "string",
  "confidence": 0,
  "frame_count": 0,
  "valid_frame_count": 0,
  "aggregated_score": 0,
  "frames": [
    {
      "filename": "string",
      "prediction": "string",
      "confidence": 0
    }
  ],
  "label_distribution": {
    "additionalProp1": {
      "count": 0,
      "total_confidence": 0,
      "avg_confidence": 0
    }
  },
  "total_processing_time": 0,
  "error": "string"
}
```

## Notes

- All video handling logic remains native/Kotlin
- Flutter just handles UI and sending the frames
- Endpoint `/upload/video` is the single source of truth for analysis
- Frame extraction already implemented in FrameExtractor.kt
- Preserve original resolution (no compression) - Already implemented
- Save frames locally temporarily - Already implemented
