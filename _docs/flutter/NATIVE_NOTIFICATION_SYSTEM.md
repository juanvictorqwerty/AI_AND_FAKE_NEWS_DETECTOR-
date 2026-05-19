# Native Notification System - Implementation Guide

## Overview

The Android notification system has been refactored to be **fully native Kotlin-based** with **zero Flutter dependencies**. This system works independently of Flutter, even when the app is fully closed or never opened.

## Architecture

### Key Components

1. **NotificationForegroundService** - Main service that handles notifications
2. **FactCheckApiService** - Native API service using OkHttp and Coroutines
3. **ConfigManager** - Manages configuration from SharedPreferences
4. **MainActivity** - Flutter bridge for configuration (optional)

### Data Flow

```
User Input (Notification)
    ↓
NotificationForegroundService
    ↓
FactCheckApiService (Native OkHttp)
    ↓
External API
    ↓
Response Processing
    ↓
Notification Update
```

## Files Created/Modified

### New Files

1. **ConfigManager.kt** - Configuration management
   - Stores base URL and auth token in SharedPreferences
   - Can be configured from Flutter or manually

2. **FactCheckApiService.kt** - Native API service
   - Uses OkHttp for HTTP requests
   - Uses Kotlin Coroutines for async operations
   - Handles errors and timeouts

### Modified Files

1. **NotificationForegroundService.kt**
   - Removed all Flutter MethodChannel communication
   - Added native API call handling
   - Uses Coroutines for async operations

2. **MainActivity.kt**
   - Removed Flutter notification result channel
   - Added configuration methods for base URL and auth token
   - Kept service control methods

3. **build.gradle.kts**
   - Added OkHttp dependency
   - Added Kotlin Coroutines dependencies
   - Added Gson dependency for JSON parsing

## How It Works

### 1. Service Startup

The service starts automatically on:
- Device boot (via BootReceiver)
- App install/update (via BootReceiver)
- Manual start from Flutter or native code

### 2. User Input

When user types in the notification:
1. RemoteInput captures the text
2. Service receives the input via ACTION_SUBMIT intent
3. Service updates notification with "Processing" status

### 3. API Call

The service makes a native API call:
1. Retrieves auth token from SharedPreferences
2. Calls fact-check API using OkHttp
3. Processes response asynchronously

### 4. Notification Update

After receiving API response:
1. Service formats the result
2. Updates the SAME notification (no new notifications)
3. Re-attaches RemoteInput for continuous chat

## Configuration

### From Flutter

```dart
// Configure base URL
const platform = MethodChannel('fact_check_channel');
await platform.invokeMethod('configureBaseUrl', {'baseUrl': 'http://your-server:4000'});

// Configure auth token
await platform.invokeMethod('configureAuthToken', {'token': 'your-jwt-token'});

// Start service
await platform.invokeMethod('startNotificationService');
```

### From Native Code

```kotlin
// Initialize ConfigManager
ConfigManager.init(context)

// Set base URL
ConfigManager.setBaseUrl("http://your-server:4000")

// Set auth token
ConfigManager.setAuthToken("your-jwt-token")

// Start service
NotificationForegroundService.startService(context)
```

### Manual Configuration

You can also manually configure by editing SharedPreferences:
- File: `app_config.xml`
- Keys:
  - `base_url` - API base URL
  - `auth_token` - Authentication token

## API Endpoint

The service calls the same endpoint as the Flutter app:

```
POST {base_url}/fact-check/search
Content-Type: application/json
Authorization: Bearer {token}

{
  "claim": "text to fact check"
}
```

### Expected Response

```json
{
  "success": true,
  "result": {
    "verdict": "True/False/Mixed",
    "explanation": "Detailed explanation",
    "sources": ["source1", "source2"]
  }
}
```

## Error Handling

The system handles various error scenarios:

1. **No Auth Token**
   - Shows: "Error: Please log in to use fact-checking"

2. **Network Error**
   - Shows: "Error: {error message}"

3. **API Error**
   - Shows: "Error: {error message from API}"

4. **Timeout**
   - 30-second timeout for connect/read/write operations

## Advantages Over Flutter-Based System

1. **No Flutter Dependency**
   - Works when app is closed
   - Works when Flutter engine is not running
   - Lightweight and efficient

2. **Better Performance**
   - Native OkHttp is faster than Flutter HTTP
   - Coroutines for efficient async operations
   - No MethodChannel overhead

3. **Reliability**
   - Service runs independently
   - Auto-starts on boot
   - Persistent notification

4. **Resource Efficiency**
   - No Flutter engine memory overhead
   - Minimal battery usage
   - Small APK size impact

## Testing

### Test the Service

1. **Start Service**
   ```kotlin
   NotificationForegroundService.startService(context)
   ```

2. **Check if Running**
   ```kotlin
   val isRunning = NotificationForegroundService.isServiceRunning()
   ```

3. **Stop Service**
   ```kotlin
   NotificationForegroundService.stopService(context)
   ```

### Test API Call

1. Ensure auth token is configured
2. Type a claim in the notification
3. Check logs for API response
4. Verify notification updates with result

## Troubleshooting

### Service Not Starting

- Check if FOREGROUND_SERVICE permission is granted
- Verify service is declared in AndroidManifest.xml
- Check logs for errors

### API Calls Failing

- Verify base URL is correct
- Check auth token is valid
- Ensure INTERNET permission is granted
- Check network connectivity

### Notification Not Updating

- Check if service is running
- Verify RemoteInput is properly attached
- Check logs for errors

## Future Enhancements

Potential improvements:

1. **Token Refresh**
   - Automatic token refresh when expired
   - Retry failed requests with new token

2. **Offline Support**
   - Cache recent results
   - Queue requests when offline

3. **Multiple Languages**
   - Support for different languages
   - Localized notifications

4. **Customizable Notifications**
   - User-configurable notification settings
   - Different notification styles

## Conclusion

The native notification system provides a robust, efficient, and Flutter-independent solution for fact-checking notifications. It maintains the same functionality as the Flutter-based system while offering better performance and reliability.
