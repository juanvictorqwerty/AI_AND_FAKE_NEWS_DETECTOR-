# Quick Reference: Thumbnail & Notification Guide

## TL;DR - Copy-Paste Solutions

### Flutter: Initialize Thumbnails
```dart
// In main()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThumbnailService().init();
  runApp(const MyApp());
}
```

### Flutter: Display Video Thumbnail
```dart
import 'package:ai_fake_news_detector/widgets/media_result/thumbnail_preview_widget.dart';

VideoThumbnailPreviewWidget(
  videoPath: videoPath,
  width: 300,
  height: 200,
  quality: 50,
  timeMs: 0,
)
```

### Flutter: Display Image Thumbnail
```dart
ImageThumbnailPreviewWidget(
  imagePath: imagePath,
  width: 300,
  height: 300,
)
```

### Flutter: Get Thumbnail Bytes
```dart
final thumbnail = await ThumbnailService().getThumbnail(
  videoPath: videoPath,
  quality: 50,
);
if (thumbnail != null) {
  // Use thumbnail data
}
```

### Flutter: Clear Cache
```dart
// Clear all
await ThumbnailService().clearCache();

// Clear only memory cache
ThumbnailService().clearMemoryCache();
```

### Android: Initialize Notification Helper
```kotlin
// In MediaAnalysisService.onCreate()
override fun onCreate() {
    super.onCreate()
    NotificationMediaHelper.init(this)
}
```

### Android: Add Image to Notification
```kotlin
NotificationMediaHelper.applyBigPictureStyle(builder, imagePath)
```

### Android: Add Video Thumbnail to Notification
```kotlin
NotificationMediaHelper.applyVideoThumbnailStyle(builder, videoPath)
```

### Android: Download Remote Image to Notification
```kotlin
// In coroutine scope
NotificationMediaHelper.downloadAndApplyBigPictureStyle(builder, imageUrl)
```

---

## Common Patterns

### Pattern 1: Show Thumbnail While Processing
```dart
class ProcessingScreen extends StatelessWidget {
  final String mediaPath;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (mediaType == 'video')
            VideoThumbnailPreviewWidget(videoPath: mediaPath)
          else
            ImageThumbnailPreviewWidget(imagePath: mediaPath),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}
```

### Pattern 2: Compact List of Media
```dart
ListView.builder(
  itemCount: mediaList.length,
  itemBuilder: (context, index) {
    final media = mediaList[index];
    return CompactMediaThumbnailWidget(
      mediaPath: media.path,
      mediaType: media.type,
      onTap: () => showDetails(media),
    );
  },
)
```

### Pattern 3: Result Display with Thumbnail
```dart
SingleChildScrollView(
  child: Column(
    children: [
      if (result.mediaType == 'video')
        VideoThumbnailPreviewWidget(
          videoPath: result.mediaPath,
          width: 400,
          height: 225,
        ),
      // ... result details
    ],
  ),
)
```

### Pattern 4: Pre-load Thumbnails
```dart
Future<void> preloadMediaThumbnails(List<String> paths) async {
  for (final path in paths) {
    await ThumbnailService().getThumbnail(videoPath: path);
  }
}
```

### Pattern 5: Thumbnail with Fallback
```dart
FutureBuilder<Uint8List?>(
  future: ThumbnailService().getThumbnail(videoPath: videoPath),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      return Image.memory(snapshot.data!);
    }
    return Container(
      color: Colors.grey,
      child: const Icon(Icons.video_library),
    );
  },
)
```

---

## Performance Tuning

### For Fast Generation (Small Previews)
```dart
quality: 30,      // Lower quality
maxWidth: 100,    // Small size
maxHeight: 100,
timeMs: 0,        // First frame
```

### For High Quality (Full Display)
```dart
quality: 70,      // Better quality
maxWidth: 800,    // Larger size
maxHeight: 800,
timeMs: 1000,     // Middle of video
```

### For Memory-Constrained Devices
```dart
quality: 40,
timeMs: 500,      // Skip first frames (often black)
// Clear memory cache frequently
ThumbnailService().clearMemoryCache();
```

---

## Debugging Checklist

- [ ] File path is valid: `File(path).exists()`
- [ ] File is readable: Check permissions
- [ ] Thumbnail service initialized: `ThumbnailService().init()`
- [ ] Video codec is supported (H.264, VP9, etc.)
- [ ] Notification channel has `IMPORTANCE_HIGH`
- [ ] BigPictureStyle bitmap is not null
- [ ] Device has enough disk space for cache

---

## API Reference at a Glance

### ThumbnailService
```dart
Future<Uint8List?> getThumbnail({
  required String videoPath,
  int quality = 50,
  int timeMs = 0,
})

Future<String?> getThumbnailPath({
  required String videoPath,
  int quality = 50,
  int timeMs = 0,
})

Future<void> init()
Future<void> clearCache()
void clearMemoryCache()
Map<String, dynamic> getCacheStats()
```

### NotificationMediaHelper (Kotlin)
```kotlin
fun init(context: Context)

fun applyBigPictureStyle(
    builder: NotificationCompat.Builder,
    imagePath: String
): Boolean

fun applyVideoThumbnailStyle(
    builder: NotificationCompat.Builder,
    videoPath: String
): Boolean

suspend fun downloadAndApplyBigPictureStyle(
    builder: NotificationCompat.Builder,
    imageUrl: String
): Boolean
```

### Widget Reference
```dart
VideoThumbnailPreviewWidget({
  required String videoPath,
  double width = 200,
  double height = 120,
  int quality = 50,
  int timeMs = 0,
  BoxFit fit = BoxFit.cover,
})

ImageThumbnailPreviewWidget({
  required String imagePath,
  double width = 200,
  double height = 200,
  BoxFit fit = BoxFit.cover,
})

CompactMediaThumbnailWidget({
  required String mediaPath,
  required String mediaType,
  VoidCallback? onTap,
})
```

---

## Common Error Solutions

| Error | Solution |
|-------|----------|
| `ThumbnailService not initialized` | Call `ThumbnailService().init()` in main() |
| `null` returned from getThumbnail | Check file exists, check permissions, try different timeMs |
| `OutOfMemoryError` | Lower quality/resolution parameters |
| `BigPictureStyle not showing` | Ensure notification channel has IMPORTANCE_HIGH |
| `Thumbnail widget not loading` | Check video codec support, verify file path |
| `Cache taking up space` | Call `clearCache()` periodically |
| `Network image fails` | Check URL validity, ensure INTERNET permission |

---

## File Locations

- **ThumbnailService**: `lib/services/thumbnail_service.dart`
- **Widgets**: `lib/widgets/media_result/thumbnail_preview_widget.dart`
- **Kotlin Helper**: `android/app/src/main/kotlin/.../NotificationMediaHelper.kt`
- **Documentation**: `_docs/VIDEO_THUMBNAIL_AND_BIGPICTURE_IMPLEMENTATION.md`

---

## Next Steps

1. ✅ Update `pubspec.yaml` with new dependencies
2. ✅ Initialize `ThumbnailService` in main.dart
3. ✅ Add widgets to processing screen
4. ✅ Add widgets to results screen
5. ✅ Initialize `NotificationMediaHelper` in MediaAnalysisService
6. ✅ Test BigPictureStyle notifications on physical device
7. ✅ Optimize quality/size for your device constraints
8. ✅ Monitor cache size and clear periodically

