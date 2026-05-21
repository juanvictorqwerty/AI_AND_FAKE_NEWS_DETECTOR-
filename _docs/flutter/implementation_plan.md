# Media Preview Caching & Visual Feedback Implementation Plan

This plan details the steps to implement media preview caching in Flutter and rich visual notifications in the Kotlin Foreground Service.

## User Review Required
Please review the proposed approach for passing the cached image to the Kotlin notification, and the architecture for the Flutter media cache.

## Proposed Changes

### 1. Flutter Caching System
- **`lib/services/media_cache.dart`** [NEW]
  Create a singleton `MediaCache` class holding:
  - `cachedFilePath` (String)
  - `cachedBytes` (Uint8List?)
  - `mediaType` (String) - 'image', 'video', 'text'
  - Method to clear cache

- **`lib/services/media_picker_service.dart`** [MODIFY]
  Update the service to write to `MediaCache` immediately after a user successfully picks a file (before navigating to the Processing Page).

### 2. Flutter UI Components
- **`lib/widgets/processing/media_preview_widget.dart`** [NEW]
  Create a widget that reads from `MediaCache` and displays:
  - Image: `Image.file`
  - Video: `video_thumbnail` generation (or a placeholder if video_thumbnail is not available, we need to add the package if missing).
  - Text: First 3-5 lines of text.

- **`lib/pages/ProcessingScreen.dart`** [MODIFY]
  - Replace `FileThumb` with `MediaPreviewWidget()`.
  - Ensure the UI matches the required Column structure (Preview -> Spinner -> Text).

- **`lib/pages/MediaResultPage.dart`** [MODIFY]
  - Insert `MediaPreviewWidget()` at the top of the result layout to reuse the exact same cached preview.

### 3. Kotlin Foreground Service Notification
- **`android/app/src/main/kotlin/com/example/ai_fake_news_detector/MediaAnalysisService.kt`** [MODIFY]
  - Modify `createNotification` and `updateNotification` to accept the `filePath` and `fileType` to generate a `BigPictureStyle`.
  - For Images: Decode using `BitmapFactory.decodeFile` with downscaling to avoid OOM.
  - For Videos: Use `ThumbnailUtils.createVideoThumbnail(filePath, MediaStore.Images.Thumbnails.MINI_KIND)`.
  - Apply `setOngoing(false)` and `setAutoCancel(true)` when the analysis completes, so the user can dismiss the success notification.

## Open Questions
1. Do you want me to add the `video_thumbnail` package to `pubspec.yaml` since it is not currently listed?
2. Should the Kotlin completion notification replace the ongoing notification, or update it in-place? (Updating in-place and changing `.setOngoing(false)` is the standard approach).

## Verification Plan
1. Select an image/video/text file and verify `MediaCache` stores it.
2. Verify `ProcessingScreen` and `MediaResultPage` display `MediaPreviewWidget` smoothly without backend fetches.
3. Verify Android notification shows the image/video thumbnail using `BigPictureStyle` and becomes dismissible upon completion.
