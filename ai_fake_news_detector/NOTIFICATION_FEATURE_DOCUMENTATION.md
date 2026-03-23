# Permanent Notification with Text Input - Feature Documentation

## Overview

This feature provides a **permanent (ongoing) notification with an inline text input field** that allows users to fact-check text instantly without opening the app. The notification remains visible even when the app is closed and works through a Foreground Service.

## Architecture

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        NOTIFICATION SHADE                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  AI Fact Checker                                        │   │
│  │  [Text Input Field] [Fact Check Button] [Stop Button]   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ RemoteInput
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    KOTLIN NATIVE LAYER                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  NotificationForegroundService.kt                       │   │
│  │  - Creates ongoing notification                         │   │
│  │  - Handles RemoteInput from notification                │   │
│  │  - Sends text to Flutter via MethodChannel              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ MethodChannel
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FLUTTER LAYER                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  notification_service.dart                              │   │
│  │  - Receives text from Kotlin                            │   │
│  │  - Calls FactCheckService API                           │   │
│  │  - Sends result back to Kotlin                          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP Request
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND API                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Fact Check Endpoint                                    │   │
│  │  - Processes claim                                      │   │
│  │  - Returns verdict and explanation                      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Kotlin Native Layer

#### NotificationForegroundService.kt
**Location:** `android/app/src/main/kotlin/com/example/ai_fake_news_detector/NotificationForegroundService.kt`

**Key Features:**
- **Foreground Service**: Runs independently of app lifecycle
- **Ongoing Notification**: Uses `setOngoing(true)` to prevent dismissal
- **RemoteInput**: Enables inline text input in notification
- **MethodChannel**: Communicates with Flutter layer

**Key Methods:**
- `startService()`: Starts the foreground service
- `stopService()`: Stops the foreground service
- `createNotification()`: Builds notification with RemoteInput
- `handleRemoteInput()`: Processes text input from notification
- `sendToFlutter()`: Sends text to Flutter via MethodChannel
- `updateNotificationWithResult()`: Updates notification with API result

#### MainActivity.kt
**Location:** `android/app/src/main/kotlin/com/example/ai_fake_news_detector/MainActivity.kt`

**Key Features:**
- Exposes FlutterEngine for service communication
- Handles MethodChannel calls from Flutter
- Manages service start/stop commands

**MethodChannel Handlers:**
- `startNotificationService`: Starts the foreground service
- `stopNotificationService`: Stops the foreground service
- `updateNotificationResult`: Updates notification with result

### 2. Flutter Layer

#### notification_service.dart
**Location:** `lib/services/notification_service.dart`

**Key Features:**
- Listens for MethodChannel calls from Kotlin
- Processes text input using FactCheckService
- Sends results back to Kotlin layer
- Manages service state

**Key Methods:**
- `_setupMethodChannel()`: Configures MethodChannel listener
- `_handleNotificationInput()`: Processes incoming text
- `_updateNotificationResult()`: Sends result to Kotlin
- `startNotificationService()`: Starts the service
- `stopNotificationService()`: Stops the service

#### permanent_fact_check.dart
**Location:** `lib/notifications/permanent_fact_check.dart`

**Key Features:**
- UI widget for controlling the notification service
- Shows service status
- Provides start/stop controls
- Displays authentication warnings

### 3. Configuration

#### AndroidManifest.xml
**Location:** `android/app/src/main/AndroidManifest.xml`

**Permissions Added:**
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

**Service Declaration:**
```xml
<service
    android:name=".NotificationForegroundService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="specialUse" />
```

## Data Flow Step-by-Step

### Step 1: User Enables Service
1. User opens the app and navigates to HomePage
2. User taps "Start Service" button in PermanentFactCheck widget
3. Flutter calls `NotificationService.startNotificationService()`
4. MethodChannel sends `startNotificationService` to Kotlin
5. `MainActivity` calls `NotificationForegroundService.startService()`
6. Service starts and creates ongoing notification

### Step 2: User Enters Text
1. User pulls down notification shade
2. User sees "AI Fact Checker" notification with text input field
3. User types text in the RemoteInput field
4. User taps "Fact Check" button

### Step 3: Text Processing
1. `NotificationForegroundService.handleRemoteInput()` is called
2. RemoteInput extracts the typed text
3. Service calls `sendToFlutter()` with the text
4. MethodChannel invokes `onNotificationInput` in Flutter

### Step 4: Flutter Processing
1. `NotificationService._handleNotificationInput()` receives the text
2. Service retrieves auth token from `AuthController`
3. Service calls `FactCheckService.searchFactCheck()` with:
   - claim: The input text
   - token: User's authentication token
4. API request is sent to backend

### Step 5: Result Handling
1. Backend processes the claim and returns result
2. `FactCheckService` returns verdict and explanation
3. `NotificationService` formats the result
4. MethodChannel sends `updateNotificationResult` to Kotlin
5. `NotificationForegroundService.updateNotificationWithResult()` updates notification
6. User sees result in notification shade

### Step 6: Service Stop
1. User taps "Stop" button in notification
2. `NotificationForegroundService` receives ACTION_STOP
3. Service calls `stopSelf()` to terminate
4. Notification is removed

## Key Implementation Details

### Notification Configuration
```kotlin
NotificationCompat.Builder(this, CHANNEL_ID)
    .setContentTitle("AI Fact Checker")
    .setContentText("Tap to enter text for fact checking")
    .setSmallIcon(R.mipmap.ic_launcher)
    .setPriority(NotificationCompat.PRIORITY_HIGH)
    .setOngoing(true)  // Makes notification non-dismissible
    .setAutoCancel(false)
    .addAction(replyAction)  // RemoteInput action
    .addAction(stopAction)   // Stop service action
```

### RemoteInput Configuration
```kotlin
val remoteInput = RemoteInput.Builder(KEY_TEXT_REPLY)
    .setLabel("Enter text to fact check...")
    .build()

val replyAction = NotificationCompat.Action.Builder(
    R.drawable.ic_send,
    "Fact Check",
    replyPendingIntent
)
    .addRemoteInput(remoteInput)
    .build()
```

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

## Usage Instructions

### For Users
1. Open the app and login (required for API access)
2. On HomePage, find "Quick Fact Check" card
3. Tap "Start Service" button
4. Pull down notification shade
5. Find "AI Fact Checker" notification
6. Type text in the input field
7. Tap "Fact Check" button
8. View result in notification

### For Developers
1. **Starting Service:**
   ```dart
   final notificationService = Get.find<NotificationService>();
   await notificationService.startNotificationService();
   ```

2. **Stopping Service:**
   ```dart
   await notificationService.stopNotificationService();
   ```

3. **Checking Status:**
   ```dart
   final isRunning = notificationService.isServiceRunning.value;
   ```

## Troubleshooting

### Service Not Starting
- Check if user is logged in (token required)
- Verify FOREGROUND_SERVICE permission is granted
- Check Android logs for errors

### Notification Not Appearing
- Verify notification channel is created
- Check POST_NOTIFICATIONS permission (Android 13+)
- Ensure service is running

### Text Input Not Working
- Verify RemoteInput is properly configured
- Check MethodChannel communication
- Review Kotlin logs for errors

### API Calls Failing
- Verify user is authenticated
- Check network connectivity
- Verify backend URL in .env file

## File Structure

```
ai_fake_news_detector/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── AndroidManifest.xml (updated)
│               ├── kotlin/com/example/ai_fake_news_detector/
│               │   ├── MainActivity.kt (updated)
│               │   └── NotificationForegroundService.kt (new)
│               └── res/
│                   └── drawable/
│                       ├── ic_send.xml (new)
│                       └── ic_close.xml (new)
├── lib/
│   ├── main.dart (updated)
│   ├── notifications/
│   │   └── permanent_fact_check.dart (updated)
│   ├── pages/
│   │   └── HomePage.dart (updated)
│   └── services/
│       ├── notification_service.dart (new)
│       ├── fact_check_service.dart (existing)
│       └── auth_controller.dart (existing)
└── NOTIFICATION_FEATURE_DOCUMENTATION.md (this file)
```

## Advanced Features (Optional)

### Quick Settings Tile
To add a Quick Settings Tile for quick access:
1. Create a TileService in Kotlin
2. Add tile to AndroidManifest.xml
3. Handle tile click to start/stop service

### Overlay Window
To show a richer UI overlay:
1. Request SYSTEM_ALERT_WINDOW permission
2. Create overlay layout in Kotlin
3. Show overlay when notification is tapped
4. Handle overlay interactions

## Performance Considerations

- **Memory**: Service runs in background, minimal memory usage
- **Battery**: Foreground service has minimal battery impact
- **Network**: API calls only when user submits text
- **Notification**: Ongoing notification uses minimal resources

## Security Considerations

- **Authentication**: Requires valid auth token
- **Data Privacy**: Text is sent to backend for processing
- **Token Storage**: Token stored securely in SharedPreferences
- **Network**: Uses HTTPS for API calls

## Future Enhancements

1. **History**: Save fact-check history locally
2. **Offline Mode**: Cache results for offline access
3. **Multiple Languages**: Support for multiple languages
4. **Voice Input**: Add voice-to-text capability
5. **Quick Actions**: Add quick action buttons for common queries
