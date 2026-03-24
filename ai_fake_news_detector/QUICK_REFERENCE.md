# Quick Reference: Permanent Notification Feature

## For Users

### How to Enable
1. Open the app
2. Log in with your credentials
3. On the home page, find "Quick Fact Check" card
4. Tap "Start Service" button
5. Pull down notification shade to see the notification

### How to Use
1. Pull down notification shade
2. Find "AI Fact Checker" notification
3. Type text in the input field
4. Tap "Fact Check" button
5. View result in notification

### How to Disable
1. Pull down notification shade
2. Find "AI Fact Checker" notification
3. Tap "Stop" button
4. Notification will be removed

## For Developers

### Key Files to Know

**Kotlin (Android):**
- `NotificationForegroundService.kt` - Manages notification and RemoteInput
- `MainActivity.kt` - Exposes FlutterEngine and handles MethodChannel

**Flutter (Dart):**
- `notification_service.dart` - Handles communication and API calls
- `permanent_fact_check.dart` - UI widget for service control

**Configuration:**
- `AndroidManifest.xml` - Permissions and service declaration

### MethodChannel Communication

**Channel Name:** `fact_check_channel`

**Kotlin → Flutter:**
```kotlin
channel.invokeMethod("onNotificationInput", text)
```

**Flutter → Kotlin:**
```dart
await _channel.invokeMethod('startNotificationService');
await _channel.invokeMethod('stopNotificationService');
await _channel.invokeMethod('updateNotificationResult', {'result': result});
```

### Starting Service Programmatically
```dart
final notificationService = Get.find<NotificationService>();
await notificationService.startNotificationService();
```

### Stopping Service Programmatically
```dart
final notificationService = Get.find<NotificationService>();
await notificationService.stopNotificationService();
```

### Checking Service Status
```dart
final notificationService = Get.find<NotificationService>();
final isRunning = notificationService.isServiceRunning.value;
```

## Troubleshooting

### Service Won't Start
- Check if user is logged in
- Verify FOREGROUND_SERVICE permission
- Check Android logs

### Notification Not Showing
- Verify notification channel exists
- Check POST_NOTIFICATIONS permission (Android 13+)
- Ensure service is running

### Text Input Not Working
- Check RemoteInput configuration
- Verify MethodChannel communication
- Review Kotlin logs

### API Calls Failing
- Verify authentication token
- Check network connectivity
- Verify backend URL in .env

## Build Commands

### Clean Build
```bash
cd ai_fake_news_detector
flutter clean
flutter pub get
```

### Run on Android
```bash
flutter run
```

### Build APK
```bash
flutter build apk
```

## File Locations

```
ai_fake_news_detector/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── AndroidManifest.xml
│               ├── kotlin/com/example/ai_fake_news_detector/
│               │   ├── MainActivity.kt
│               │   └── NotificationForegroundService.kt
│               └── res/drawable/
│                   ├── ic_send.xml
│                   └── ic_close.xml
├── lib/
│   ├── main.dart
│   ├── notifications/
│   │   └── permanent_fact_check.dart
│   ├── pages/
│   │   └── HomePage.dart
│   └── services/
│       └── notification_service.dart
├── NOTIFICATION_FEATURE_DOCUMENTATION.md
├── IMPLEMENTATION_SUMMARY.md
└── QUICK_REFERENCE.md
```

## Important Notes

1. **Authentication Required**: User must be logged in to use the feature
2. **Ongoing Notification**: Notification cannot be dismissed by swiping
3. **Background Execution**: Works even when app is closed
4. **API Dependent**: Requires backend API for fact-checking
5. **Network Required**: Needs internet connection for API calls

## Support

For detailed documentation, see:
- `NOTIFICATION_FEATURE_DOCUMENTATION.md` - Complete architecture and data flow
- `IMPLEMENTATION_SUMMARY.md` - List of all changes made
