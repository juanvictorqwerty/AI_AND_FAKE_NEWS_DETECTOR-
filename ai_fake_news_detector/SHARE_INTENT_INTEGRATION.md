# Share Intent Integration Documentation

## Overview

This document describes the Android Share Intent integration that allows users to share images and videos from other apps (Gallery, WhatsApp, Telegram, Browser, etc.) directly to the AI Fake News Detector app for analysis.

## Architecture

### Components Created

1. **ShareReceiverActivity.kt** - Lightweight activity that receives shared media
2. **activity_share_receiver.xml** - Minimal UI layout for preview and results
3. **AndroidManifest.xml** - Updated with intent filters for `ACTION_SEND`

### Integration Points

The ShareReceiverActivity integrates with existing infrastructure:

- **MediaUploadService** - Handles file upload to FastAPI backend
- **AnalysisResult** - Data class for analysis results
- **ConfigManager** - Manages API endpoints and auth tokens

## How It Works

### 1. User Shares Media

When a user shares an image or video from another app:
- Android shows a share sheet
- The app appears as "AFND" (or app label)
- User selects the app

### 2. ShareReceiverActivity Receives Intent

```kotlin
// Intent filters in AndroidManifest.xml
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="image/*" />
</intent-filter>
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="video/*" />
</intent-filter>
```

### 3. URI to File Conversion

The activity converts the shared `content://` URI to a temporary file:

```kotlin
private suspend fun convertUriToFile(uri: Uri, mimeType: String): File? {
    // Takes persistable URI permission if available
    // Determines file extension from MIME type
    // Creates temporary file in cache directory
    // Copies content from URI to file
}
```

**Key Features:**
- Handles `content://` URIs from content providers
- Takes persistable URI permissions when supported
- Creates temporary files in app cache directory
- Automatic cleanup on activity destroy

### 4. Upload and Analysis

The activity calls existing MediaUploadService methods:

```kotlin
// Upload file to backend
val uploadResponse = uploadService.uploadFile(file.absolutePath, fileType)

// Poll for analysis results
val result = uploadService.pollUntilComplete(
    uploadResponse.fileId,
    onStatusUpdate = { analysisResult ->
        // Update UI with progress
    }
)
```

**No reimplementation** - uses existing upload and polling logic.

### 5. Result Display

Results are displayed in a lightweight overlay UI:

- **Preview area** - Shows media file name
- **Loading indicator** - Shows upload/analysis progress
- **Result text** - Displays "Fake" or "Real" label
- **Confidence score** - Shows percentage confidence
- **Status message** - Color-coded (red for fake, green for real)

### 6. Auto-Close

The activity automatically closes after 5 seconds (configurable via `AUTO_CLOSE_DELAY_MS`).

## UI Components

### Layout Structure

```
┌─────────────────────────────────┐
│  Media Analysis        [Close]  │
├─────────────────────────────────┤
│                                 │
│      [Media Preview Area]       │
│                                 │
├─────────────────────────────────┤
│         [Loading...]            │
│         Status Message          │
├─────────────────────────────────┤
│         Result Label            │
│       Confidence: XX.XX%        │
├─────────────────────────────────┤
│   [Retry]    [Open Full App]    │
└─────────────────────────────────┘
```

### UI States

1. **Initial State**
   - Preview area shows "Media Preview"
   - Status: "Processing shared media..."

2. **Uploading State**
   - Progress bar visible
   - Status: "Uploading media..."

3. **Analyzing State**
   - Progress bar visible
   - Status: "Analyzing media..."

4. **Success State**
   - Result label visible (Fake/Real)
   - Confidence percentage visible
   - Status message with icon
   - Retry and Open Full App buttons

5. **Error State**
   - Error message in red
   - Retry button visible
   - Open Full App button visible

## Integration with Existing Services

### MediaUploadService Methods Used

1. **uploadFile(filePath: String, fileType: String): UploadResponse**
   - Uploads file to `/upload` endpoint
   - Returns `fileId` for polling

2. **pollUntilComplete(fileId: String, ...): AnalysisResult**
   - Polls `/results/{fileId}` endpoint
   - Returns completed `AnalysisResult`

### Data Classes Used

- **UploadResponse** - Contains `fileId`, `success`, `message`
- **AnalysisResult** - Contains `label`, `confidence`, `status`

## Permissions

### URI Permissions

The activity handles temporary URI permissions granted by the sharing app:

```kotlin
try {
    contentResolver.takePersistableUriPermission(
        uri,
        Intent.FLAG_GRANT_READ_URI_PERMISSION
    )
} catch (e: SecurityException) {
    // Not all URIs support persistable permissions
}
```

### No Storage Permissions Required

Since we use `content://` URIs and ContentResolver, no additional storage permissions are needed.

## Testing

### Test Scenarios

1. **Share from Gallery**
   - Open Gallery app
   - Select an image
   - Share → Select "AFND"
   - Verify analysis completes

2. **Share from WhatsApp**
   - Open WhatsApp
   - Long-press an image/video
   - Share → Select "AFND"
   - Verify analysis completes

3. **Share from Telegram**
   - Open Telegram
   - Long-press an image/video
   - Share → Select "AFND"
   - Verify analysis completes

4. **Share from Browser**
   - Long-press an image in browser
   - Share → Select "AFND"
   - Verify analysis completes

### Expected Behavior

- Activity opens immediately
- Preview shows file name
- Loading indicator appears
- Status updates during upload/analysis
- Result displays with confidence
- Auto-closes after 5 seconds
- Temporary file cleaned up

## Configuration

### Auto-Close Delay

Modify `AUTO_CLOSE_DELAY_MS` in `ShareReceiverActivity.kt`:

```kotlin
private const val AUTO_CLOSE_DELAY_MS = 5000L // 5 seconds
```

### Supported MIME Types

Currently supports:
- `image/*` (JPEG, PNG, WebP, GIF)
- `video/*` (MP4, MOV, AVI)

To add more types, update:
1. `SUPPORTED_IMAGE_TYPES` or `SUPPORTED_VIDEO_TYPES` in ShareReceiverActivity
2. Intent filters in AndroidManifest.xml

## Troubleshooting

### Issue: App doesn't appear in share sheet

**Solution:**
- Verify AndroidManifest.xml has correct intent filters
- Check that `android:exported="true"` is set
- Rebuild and reinstall the app

### Issue: "No media content received" error

**Solution:**
- Verify the sharing app grants URI permission
- Check that the URI is not null
- Ensure the MIME type is supported

### Issue: Upload fails with 401

**Solution:**
- Verify auth token is configured via `ConfigManager.setAuthToken()`
- Check that the token is valid and not expired

### Issue: Analysis times out

**Solution:**
- Check network connectivity
- Verify backend API is accessible
- Increase timeout in `MediaUploadService`

## Future Enhancements

### Optional Features

1. **Image Thumbnail Preview**
   - Load actual image thumbnail using Glide/Coil
   - Show video thumbnail for videos

2. **Share Multiple Files**
   - Handle `ACTION_SEND_MULTIPLE`
   - Process multiple files in batch

3. **Custom Result Display**
   - Show detailed probabilities
   - Display processing time
   - Show frame-by-frame results for videos

4. **Share History**
   - Save shared media analysis history
   - Allow reviewing past analyses

5. **Deep Link Integration**
   - Open specific analysis result in main app
   - Share analysis result with others

## File Locations

```
ai_fake_news_detector/android/app/src/main/
├── kotlin/com/example/ai_fake_news_detector/
│   └── ShareReceiverActivity.kt
├── res/
│   └── layout/
│       └── activity_share_receiver.xml
└── AndroidManifest.xml
```

## Dependencies

No new dependencies required. Uses existing:
- AndroidX AppCompat
- Kotlin Coroutines
- OkHttp (via MediaUploadService)

## Summary

The Share Intent integration provides a seamless way for users to analyze media from any app without leaving their current workflow. It leverages existing upload and analysis infrastructure, ensuring consistency with the main app's functionality while maintaining a lightweight, focused user experience.
