# Media Upload Feature - Quick Reference

## 📁 Files Created

### Models
- [`lib/models/upload_response.dart`](lib/models/upload_response.dart) - Upload response model
- [`lib/models/processing_status.dart`](lib/models/processing_status.dart) - Processing status model
- [`lib/models/analysis_result.dart`](lib/models/analysis_result.dart) - Analysis result model

### Services
- [`lib/services/media_api_service.dart`](lib/services/media_api_service.dart) - API communication

### Controllers
- [`lib/controllers/media_upload_controller.dart`](lib/controllers/media_upload_controller.dart) - State management

### Screens
- [`lib/pages/ProcessingScreen.dart`](lib/pages/ProcessingScreen.dart) - Upload/processing UI

### Updated Files
- [`lib/pages/MediaResultPage.dart`](lib/pages/MediaResultPage.dart) - Display analysis results
- [`lib/pages/MediaPickerPage.dart`](lib/pages/MediaPickerPage.dart) - Upload integration
- [`lib/main.dart`](lib/main.dart) - Service registration and routes

## 🚀 Quick Start

### 1. Configure Backend URL
Add to `assets/.env`:
```
Base_url_fastapi=http://127.0.0.1:8000
```

### 2. Run the App
```bash
flutter run
```

### 3. Test the Flow
1. Open MediaPickerPage
2. Select image/video
3. Click "Upload and Analyze"
4. Watch progress
5. View results

## 🔌 API Endpoints Required

### Upload
```
POST /upload
Content-Type: multipart/form-data
Body: file

Response:
{
  "success": true,
  "file_id": "abc123",
  "message": "File uploaded successfully"
}
```

### Status
```
GET /results/{file_id}/status

Response:
{
  "status": "processing",
  "file_id": "abc123",
  "progress": 50
}
```

### Result
```
GET /results/{file_id}

Response:
{
  "file_id": "abc123",
  "label": "AI",
  "confidence": 0.85,
  "probabilities": {
    "ai": 0.85,
    "human": 0.15
  }
}
```

## 🎯 Key Features

✅ File selection (image/video)
✅ File validation (20MB max, 60s video)
✅ Upload with progress indicator
✅ Processing status polling (every 2s)
✅ Result display (AI/Human label)
✅ Confidence score and probabilities
✅ Error handling with retry
✅ Timeout handling (5 minutes)
✅ Clean state management (GetX)

## 📊 State Flow

```
Idle → Uploading → Processing → Completed
  ↓         ↓           ↓          ↓
Failed    Failed      Failed    Show Result
```

## 🔧 Usage Example

```dart
// Get controller
final controller = Get.find<MediaUploadController>();

// Start upload and processing
await controller.uploadAndProcess(filePath, fileType);

// Check state
if (controller.isCompleted) {
  final result = controller.analysisResult.value;
  print('Label: ${result.label}');
  print('Confidence: ${result.confidencePercentage}');
}

// Retry if failed
if (controller.isFailed) {
  await controller.retry();
}

// Reset state
controller.resetState();
```

## 🎨 UI Components

### ProcessingScreen
- Linear progress for upload
- Circular progress for processing
- File preview
- Cancel button

### MediaResultPage
- Result card (AI/Human)
- Confidence score
- Probability bars
- Error display
- Action buttons

### MediaPickerPage
- File picker buttons
- File preview
- File info
- Upload button

## ⚙️ Configuration

### Timeouts
- Upload: 2 minutes
- Status check: 30 seconds
- Processing: 5 minutes

### Retry
- Max attempts: 3
- Backoff: Exponential (2s, 4s, 6s)

### Polling
- Interval: 2 seconds
- Timeout: 5 minutes

## 🐛 Troubleshooting

### Upload fails
- Check backend URL in `.env`
- Verify backend is running
- Check network connectivity

### Processing timeout
- Increase timeout in `MediaApiService`
- Check backend processing time

### Navigation issues
- Verify routes in `main.dart`
- Check GetX service registration

### State not updating
- Ensure GetX services are registered
- Check `ever()` listeners

## 📝 Testing Checklist

- [ ] Pick image from gallery
- [ ] Pick video from gallery
- [ ] Validate file size (< 20MB)
- [ ] Validate video duration (< 60s)
- [ ] Upload with progress
- [ ] Processing status updates
- [ ] Result display
- [ ] Error handling
- [ ] Retry functionality
- [ ] Cancel upload

## 🔗 Related Documentation

- [Implementation Plan](MEDIA_UPLOAD_IMPLEMENTATION_PLAN.md)
- [Architecture Diagrams](MEDIA_UPLOAD_ARCHITECTURE.md)
- [Implementation Summary](MEDIA_UPLOAD_IMPLEMENTATION_SUMMARY.md)

## 📞 Support

For issues or questions:
1. Check troubleshooting section
2. Review architecture diagrams
3. Verify API endpoints
4. Check backend logs
