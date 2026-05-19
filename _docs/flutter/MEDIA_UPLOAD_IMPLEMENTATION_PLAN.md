# Media Upload and Result Retrieval Implementation Plan

## Overview
This plan outlines the implementation of a complete media upload and result retrieval feature for the AI Fake News Detector Flutter app. The feature will allow users to upload images/videos to a FastAPI backend and retrieve AI analysis results.

## Current State Analysis

### Existing Components
- **MediaPickerService**: Already handles file picking and validation (20MB max, 60s video limit)
- **MediaPickerPage**: UI for selecting media files
- **MediaResultPage**: Currently shows selected media preview (needs update for results)
- **Dependencies**: `http` package already available for networking

### Architecture Pattern
- Uses GetX for state management and dependency injection
- Services extend `GetxService`
- Follows existing patterns in `FactCheckService`

## Implementation Plan

### Phase 1: Data Models

#### 1.1 Create Upload Response Model
**File**: `lib/models/upload_response.dart`

```dart
class UploadResponse {
  final bool success;
  final String fileId;
  final String message;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  
  // Constructor, fromJson, toJson methods
}
```

#### 1.2 Create Processing Status Model
**File**: `lib/models/processing_status.dart`

```dart
class ProcessingStatus {
  final String status; // "pending", "processing", "completed", "failed"
  final String fileId;
  final String? message;
  final int? progress; // 0-100
  
  // Constructor, fromJson, toJson methods
}
```

#### 1.3 Create Analysis Result Model
**File**: `lib/models/analysis_result.dart`

```dart
class AnalysisResult {
  final String fileId;
  final String label; // "AI" or "Human"
  final double confidence; // 0.0 to 1.0
  final Map<String, double> probabilities; // {"ai": 0.85, "human": 0.15}
  final String? errorMessage;
  final DateTime? processedAt;
  
  // Constructor, fromJson, toJson methods
  // Helper getters: isAi, isHuman, confidencePercentage
}
```

### Phase 2: API Service

#### 2.1 Create MediaApiService
**File**: `lib/services/media_api_service.dart`

**Responsibilities**:
- Upload files via multipart POST request
- Poll processing status endpoint
- Retrieve final analysis results
- Handle network errors and retries

**Key Methods**:
```dart
class MediaApiService extends GetxService {
  // Upload file to backend
  Future<UploadResponse> uploadFile(String filePath, String fileType);
  
  // Poll processing status
  Future<ProcessingStatus> getProcessingStatus(String fileId);
  
  // Get final analysis result
  Future<AnalysisResult> getAnalysisResult(String fileId);
  
  // Poll until completion with timeout
  Future<AnalysisResult> pollUntilComplete(String fileId, {
    Duration timeout = const Duration(minutes: 5),
    Duration interval = const Duration(seconds: 2),
  });
}
```

**Implementation Details**:
- Use `http.MultipartRequest` for file upload
- Implement exponential backoff for polling
- Add timeout handling (5 minutes default)
- Retry mechanism (3 attempts for network errors)
- Progress tracking during upload

### Phase 3: State Management

#### 3.1 Create MediaUploadController
**File**: `lib/controllers/media_upload_controller.dart`

**State Variables**:
- `uploadState`: idle, uploading, processing, completed, failed
- `uploadProgress`: 0.0 to 1.0
- `processingStatus`: current status string
- `fileId`: uploaded file ID
- `analysisResult`: final result
- `errorMessage`: error details

**Key Methods**:
```dart
class MediaUploadController extends GetxController {
  // State observables
  final uploadState = UploadState.idle.obs;
  final uploadProgress = 0.0.obs;
  final processingStatus = ''.obs;
  final fileId = ''.obs;
  final analysisResult = Rxn<AnalysisResult>();
  final errorMessage = ''.obs;
  
  // Actions
  Future<void> uploadAndProcess(String filePath, String fileType);
  void resetState();
  void retry();
}
```

### Phase 4: UI Screens

#### 4.1 Create ProcessingScreen
**File**: `lib/pages/ProcessingScreen.dart`

**Features**:
- Show upload progress indicator (linear)
- Display "Uploading..." message during upload
- Show "Processing..." message during analysis
- Display file preview (image/video)
- Cancel button (optional)
- Auto-navigate to result screen when complete

**UI Components**:
```dart
class ProcessingScreen extends StatelessWidget {
  // Progress indicator
  // Status message
  // File preview
  // Cancel button
}
```

#### 4.2 Update MediaResultPage
**File**: `lib/pages/MediaResultPage.dart` (existing)

**New Features**:
- Display analysis result (AI/Human label)
- Show confidence score (percentage)
- Display probabilities (ai vs human)
- Show error message if processing failed
- "Try Again" button for failed uploads
- "Upload New" button to start over

**UI Components**:
```dart
// Result card with label and confidence
// Probability bars (ai vs human)
// Error state display
// Action buttons
```

#### 4.3 Update MediaPickerPage
**File**: `lib/pages/MediaPickerPage.dart` (existing)

**Changes**:
- Add "Upload and Analyze" button
- Navigate to ProcessingScreen after file selection
- Disable buttons during upload

### Phase 5: Integration and Flow

#### 5.1 Complete User Flow
```
1. User opens MediaPickerPage
2. User selects image/video from gallery
3. File is validated (size, duration)
4. User clicks "Upload and Analyze"
5. Navigate to ProcessingScreen
6. Show upload progress (0-100%)
7. Show "Processing..." after upload complete
8. Poll backend for status every 2 seconds
9. When status = "completed", navigate to MediaResultPage
10. Display analysis results (AI/Human, confidence, probabilities)
11. If status = "failed", show error with retry option
```

#### 5.2 Error Handling
- Network errors: Show retry button
- Upload timeout: Show timeout message with retry
- Processing timeout: Show timeout with option to check later
- Invalid file: Show validation error
- Server errors: Show error message with retry

#### 5.3 State Management Flow
```
MediaPickerPage → MediaUploadController → ProcessingScreen → MediaResultPage
     ↓                    ↓                    ↓                ↓
  Pick file         Upload file          Show progress     Show result
  Validate          Poll status          Update status     Display analysis
  Navigate          Get result           Navigate          Retry/Upload new
```

## File Structure

```
lib/
├── models/
│   ├── upload_response.dart          (NEW)
│   ├── processing_status.dart        (NEW)
│   └── analysis_result.dart          (NEW)
├── services/
│   ├── media_picker_service.dart     (EXISTING - no changes)
│   └── media_api_service.dart        (NEW)
├── controllers/
│   └── media_upload_controller.dart  (NEW)
├── pages/
│   ├── MediaPickerPage.dart          (UPDATE - add upload button)
│   ├── ProcessingScreen.dart         (NEW)
│   └── MediaResultPage.dart          (UPDATE - show results)
└── widgets/
    └── result_card_widget.dart       (NEW - optional)
```

## API Endpoints (Expected)

### Upload Endpoint
- **URL**: `POST /upload`
- **Content-Type**: `multipart/form-data`
- **Body**: File field named "file"
- **Response**:
```json
{
  "success": true,
  "file_id": "abc123",
  "message": "File uploaded successfully",
  "file_name": "video.mp4",
  "file_type": "video",
  "file_size": 1024000
}
```

### Status Endpoint
- **URL**: `GET /results/{file_id}/status`
- **Response**:
```json
{
  "status": "processing",
  "file_id": "abc123",
  "message": "Analyzing media...",
  "progress": 50
}
```

### Result Endpoint
- **URL**: `GET /results/{file_id}`
- **Response**:
```json
{
  "file_id": "abc123",
  "label": "AI",
  "confidence": 0.85,
  "probabilities": {
    "ai": 0.85,
    "human": 0.15
  },
  "processed_at": "2024-01-15T10:30:00Z"
}
```

## Implementation Order

1. **Step 1**: Create data models (upload_response, processing_status, analysis_result)
2. **Step 2**: Create MediaApiService with upload and polling logic
3. **Step 3**: Create MediaUploadController for state management
4. **Step 4**: Create ProcessingScreen UI
5. **Step 5**: Update MediaResultPage to display results
6. **Step 6**: Update MediaPickerPage to integrate upload flow
7. **Step 7**: Test complete flow and handle edge cases

## Key Features

### Upload Progress
- Linear progress indicator showing upload percentage
- Real-time updates during file transfer
- Disable UI interactions during upload

### Processing Status
- Poll backend every 2 seconds
- Show "Processing..." with animated indicator
- Display progress percentage if available
- Timeout after 5 minutes

### Result Display
- Clear AI/Human label with color coding
- Confidence score as percentage
- Visual probability bars
- Error state with retry option

### Error Handling
- Network connectivity checks
- Retry mechanism (3 attempts)
- Timeout handling
- User-friendly error messages
- Graceful degradation

## Testing Checklist

- [ ] Upload image file (< 20MB)
- [ ] Upload video file (< 20MB, < 60s)
- [ ] Upload file > 20MB (should fail validation)
- [ ] Upload video > 60s (should fail validation)
- [ ] Network error during upload (should retry)
- [ ] Processing timeout (should show error)
- [ ] Successful analysis result display
- [ ] Failed processing error display
- [ ] Retry functionality
- [ ] Cancel upload (optional)

## Dependencies

### Existing (No Changes)
- `get: ^4.7.3` - State management
- `http: ^1.2.0` - HTTP requests
- `image_picker: ^1.0.7` - File picking
- `video_player: ^2.8.2` - Video playback

### No New Dependencies Required
All required packages are already in pubspec.yaml.

## Notes

- Backend API endpoints are assumed based on requirements
- Actual API response structure may need adjustment
- Polling interval and timeout are configurable
- Progress tracking depends on backend support
- File validation already implemented in MediaPickerService

## Success Criteria

1. User can select image/video from gallery
2. File is validated before upload (size, duration)
3. File uploads with progress indicator
4. Processing status is polled and displayed
5. Analysis result shows AI/Human label with confidence
6. Probabilities are displayed visually
7. Errors are handled gracefully with retry options
8. UI is responsive and user-friendly
9. Code is clean, modular, and maintainable
10. No platform-specific native code required
