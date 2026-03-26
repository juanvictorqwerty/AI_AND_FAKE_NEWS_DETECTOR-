# Media Picker Feature Documentation

## Overview

This document describes the implementation of the media picker feature for the AI & Fake News Detector Flutter application. The feature allows users to pick images or videos from their device gallery with comprehensive validation and preview capabilities.

## Features

### 1. File Picking
- **Image Selection**: Pick images from gallery
- **Video Selection**: Pick videos from gallery
- **Any Media**: Pick either images or videos from gallery
- **Gallery Access**: Uses `image_picker` package for reliable gallery access

### 2. Validation Rules
- **File Size Limit**: Maximum 20MB per file
- **Video Duration Limit**: Maximum 60 seconds for videos
- **Clear Error Messages**: User-friendly error messages for validation failures

### 3. User Experience
- **Media Preview**:
  - Image preview for images
  - Video player with play/pause controls for videos
- **Loading Indicators**: Shows loading state while processing metadata
- **File Information**: Displays file size, type, and duration (for videos)
- **Error Handling**: Graceful error handling without app crashes

### 4. Technical Implementation
- **Efficient File Reading**: Reads file size before loading into memory
- **Video Duration Extraction**: Uses `video_player` package for accurate duration
- **Memory Optimization**: Proper disposal of video controllers
- **Robust Permission Handling**: Comprehensive permission management across Android versions

### 5. Permission Handling (NEW)
- **Android Version Detection**: Automatically detects Android version and uses appropriate permissions
  - Android 13+ (API 33+): Uses `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO`
  - Android ≤12: Uses `READ_EXTERNAL_STORAGE`
- **Permanently Denied Detection**: Detects when permissions are permanently denied
- **Settings Guidance**: Shows dialog to guide users to app settings when permissions are permanently denied
- **Permission Caching**: Caches permission status to avoid repeated requests
- **Debug Logging**: Comprehensive logging for permission state debugging

## Architecture

### Service Layer: `MediaPickerService`

The `MediaPickerService` is a GetX service that handles all media picking logic:

```dart
class MediaPickerService extends GetxService {
  // Validation constants
  static const int maxFileSizeBytes = 20 * 1024 * 1024; // 20MB
  static const int maxVideoDurationSeconds = 60; // 60 seconds
  
  // Methods
  Future<Map<String, dynamic>> checkAndRequestMediaPermissions()
  Future<Map<String, dynamic>> pickImage()
  Future<Map<String, dynamic>> pickVideo()
  Future<Map<String, dynamic>> pickMedia()
  Future<Map<String, dynamic>> _validateVideoDuration(String videoPath)
  Future<Map<String, dynamic>> _handleAndroidPermissions()
  Future<Map<String, dynamic>> _handleIOSPermissions()
  Future<bool> openAppSettings()
  void resetPermissionCache()
  String getFileSizeFormatted(int bytes)
  String getDurationFormatted(int seconds)
}
```

**Key Features:**
- Returns structured results with success status, file path, and error messages
- **Robust permission handling** across Android versions (13+ and ≤12)
- Detects permanently denied permissions and guides to app settings
- Caches permission status to avoid repeated requests
- Comprehensive debug logging for permission states
- Validates file size and video duration
- Provides utility methods for formatting file size and duration

### UI Layer: `MediaPickerPage`

The `MediaPickerPage` provides a clean, intuitive interface for picking and previewing media:

**Components:**
- Loading indicator during processing
- Media preview (image or video player)
- File information display
- Error message display
- Action buttons for picking different media types
- Proceed button for validated files

**User Flow:**
1. User opens the MediaPickerPage
2. User selects a media type (Image, Video, or Any Media)
3. App shows loading indicator while processing
4. App validates the selected file
5. If valid, shows preview and file information
6. If invalid, shows error message
7. User can proceed with validated file or pick another

### Result Layer: `MediaResultPage`

The `MediaResultPage` displays the selected and validated media:

**Components:**
- Media preview (image or video player)
- File metadata display
- Upload button (placeholder for backend integration)
- Pick another file button

## File Structure

```
ai_fake_news_detector/
├── lib/
│   ├── services/
│   │   └── media_picker_service.dart    # Media picking and validation logic
│   ├── pages/
│   │   ├── MediaPickerPage.dart         # UI for picking and previewing media
│   │   ├── MediaResultPage.dart         # UI for displaying selected media
│   │   └── HomePage.dart                # Updated with navigation to MediaPickerPage
│   └── main.dart                        # Updated with service registration and routes
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml          # Updated with storage permissions
└── pubspec.yaml                         # Updated with new dependencies
```

## Dependencies Added

```yaml
dependencies:
  image_picker: ^1.0.7    # For picking images and videos from gallery
  video_player: ^2.8.2    # For video playback and duration extraction
  path_provider: ^2.1.2   # For file path handling
```

## Permissions

### Android Permissions (AndroidManifest.xml)

```xml
<!-- Storage permissions for media picker -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

**Note:**
- `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` are for Android 13+ (API 33+)
- `READ_EXTERNAL_STORAGE` is for Android 12 and below (with `maxSdkVersion="32"`)

### Permission Handling Flow

The service implements a robust permission handling flow:

1. **Check Cached Status**: First checks if permission is already granted (cached)
2. **Platform Detection**: Determines if running on Android or iOS
3. **Android Version Detection**:
   - Tries Android 13+ permissions first (`Permission.photos` and `Permission.videos`)
   - Falls back to storage permission for older versions (`Permission.storage`)
4. **Permission Request**: Requests appropriate permissions based on platform
5. **Status Evaluation**:
   - **Granted**: Proceeds with file picking
   - **Denied**: Shows error message
   - **Permanently Denied**: Shows dialog with button to open app settings
6. **Caching**: Caches granted permission status to avoid repeated requests

### Permanently Denied Permissions

When permissions are permanently denied, the app:
1. Shows a user-friendly error message
2. Displays an alert dialog with:
   - Explanation of why permission is needed
   - Button to open app settings
   - Cancel button
3. Allows user to manually enable permission in settings
4. Resets permission cache when user returns from settings

### Debug Logging

The service includes comprehensive logging for debugging permission issues:
- Permission check start
- Current permission status
- Permission request results
- Android version detection
- Error messages with stack traces

## Usage

### 1. From HomePage

The "Upload Media" button on the HomePage navigates to the MediaPickerPage:

```dart
BigButton(
  text: "Upload Media", 
  onTap: (){
    Navigator.push(
      context,
      MaterialPageRoute(builder:(context)=>const MediaPickerPage()),
    );
  }, 
  color: Colors.deepPurpleAccent
)
```

### 2. Using MediaPickerService Directly

You can also use the MediaPickerService directly in your code:

```dart
// Get the service instance
final mediaPickerService = Get.find<MediaPickerService>();

// Pick an image
final result = await mediaPickerService.pickImage();
if (result['success']) {
  final filePath = result['filePath'];
  final fileSize = result['fileSize'];
  // Use the validated file
} else {
  final errorMessage = result['message'];
  // Show error to user
}

// Pick a video
final result = await mediaPickerService.pickVideo();
if (result['success']) {
  final filePath = result['filePath'];
  final fileSize = result['fileSize'];
  final duration = result['duration'];
  // Use the validated file
}

// Pick any media (image or video)
final result = await mediaPickerService.pickMedia();
if (result['success']) {
  final filePath = result['filePath'];
  final fileType = result['fileType']; // 'image' or 'video'
  final fileSize = result['fileSize'];
  final duration = result['duration']; // Only for videos
  // Use the validated file
}
```

### 3. Formatting Utilities

```dart
final mediaPickerService = Get.find<MediaPickerService>();

// Format file size
final formattedSize = mediaPickerService.getFileSizeFormatted(1500000);
// Returns: "1.43 MB"

// Format video duration
final formattedDuration = mediaPickerService.getDurationFormatted(90);
// Returns: "1:30"
```

## Validation Flow

### Image Validation

1. User selects an image from gallery
2. App reads file size
3. If file size > 20MB, show error: "Image must be less than 20MB (current: X.XXMB)"
4. If file size ≤ 20MB, return success with file path and size

### Video Validation

1. User selects a video from gallery
2. App reads file size
3. If file size > 20MB, show error: "Video must be less than 20MB (current: X.XXMB)"
4. If file size ≤ 20MB, initialize video controller
5. Read video duration
6. If duration > 60 seconds, show error: "Video must be under 60 seconds (current: Xs)"
7. If duration ≤ 60 seconds, return success with file path, size, and duration

## Error Handling

The implementation includes comprehensive error handling:

1. **Permission Denied**: Shows message "Storage permission is required to access gallery"
2. **No File Selected**: Shows message "No file selected" or "No video selected"
3. **File Too Large**: Shows message with current file size
4. **Video Too Long**: Shows message with current duration
5. **Processing Errors**: Shows generic error message with details

All errors are caught and displayed to the user without crashing the app.

## Performance Optimizations

1. **Lazy Loading**: Video controller is only initialized when needed
2. **Memory Management**: Video controllers are properly disposed when not needed
3. **Efficient File Reading**: File size is read before loading into memory
4. **Quality Preservation**: Images are picked with 100% quality for preview

## Future Enhancements

### Planned Features

1. **Camera Capture**: Allow taking photos/videos directly from camera
2. **Multiple File Selection**: Allow selecting multiple files at once
3. **File Compression**: Optional compression before upload
4. **Cloud Storage Integration**: Direct upload to cloud storage
5. **Advanced Video Editing**: Trim videos before upload

### Backend Integration

To integrate with a backend, update the `MediaResultPage` upload button:

```dart
BigButton(
  text: 'Upload to Server',
  onTap: () async {
    final result = await uploadService.uploadMedia(
      filePath: _filePath!,
      fileType: _fileType!,
    );
    
    if (result['success']) {
      // Handle successful upload
    } else {
      // Handle upload error
    }
  },
  color: Colors.green,
)
```

## Testing

### Manual Testing Checklist

- [ ] Pick image from gallery
- [ ] Pick video from gallery
- [ ] Pick any media from gallery
- [ ] Verify image preview displays correctly
- [ ] Verify video player works with play/pause
- [ ] Verify file size displays correctly
- [ ] Verify video duration displays correctly
- [ ] Test with file larger than 20MB (should show error)
- [ ] Test with video longer than 60 seconds (should show error)
- [ ] Test permission denial (should show error message)
- [ ] Test canceling file selection (should handle gracefully)
- [ ] Test navigation between pages
- [ ] Test back button functionality

### Automated Testing

```dart
// Example test for MediaPickerService
test('should reject file larger than 20MB', () async {
  final service = MediaPickerService();
  // Mock file picker to return large file
  // Verify error message is returned
});

test('should reject video longer than 60 seconds', () async {
  final service = MediaPickerService();
  // Mock video picker to return long video
  // Verify error message is returned
});
```

## Troubleshooting

### Common Issues

1. **Permission Denied Error**
   - **Check AndroidManifest.xml**: Ensure permissions are correctly configured
   - **Check Android Version**: Android 13+ requires `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO`
   - **Check App Settings**: User may have permanently denied permission
   - **Solution**: Use the "Open Settings" button in the permission dialog to enable manually

2. **Permission Permanently Denied**
   - **Symptom**: App shows "Permission permanently denied" message
   - **Solution**:
     - Click "Open Settings" in the dialog
     - Navigate to Permissions
     - Enable Storage or Photos permission
     - Return to app

3. **Video Not Playing**
   - Ensure video_player package is properly initialized
   - Check video format is supported (MP4, MOV, AVI, MKV)
   - Verify video file is not corrupted

4. **File Size Not Detected**
   - Ensure path_provider package is properly configured
   - Check file exists at the specified path
   - Verify file is not being used by another process

5. **App Crashes on File Selection**
   - Check all dependencies are properly installed
   - Verify AndroidManifest.xml has correct permissions
   - Check for null safety issues in file handling

6. **Permission Request Not Showing**
   - **Cause**: Permission may be cached as granted
   - **Solution**: Call `resetPermissionCache()` to force re-request
   - **Debug**: Check console logs for permission state messages

### Debug Logs

The service includes comprehensive logging. Check console output for:
- `MediaPickerService: Checking media permissions...`
- `MediaPickerService: Android 13+ permissions - Photos: X, Videos: Y`
- `MediaPickerService: Storage permission status: Z`
- `MediaPickerService: Requesting permissions...`
- `MediaPickerService: Permission granted (Android 13+)`
- `MediaPickerService: Permission permanently denied`

These logs help identify where permission handling is failing.

## Conclusion

The media picker feature provides a robust, user-friendly solution for selecting and validating media files in the AI & Fake News Detector app. The implementation follows Flutter best practices with proper separation of concerns, comprehensive error handling, and optimized performance.

For questions or issues, please refer to the troubleshooting section or contact the development team.
