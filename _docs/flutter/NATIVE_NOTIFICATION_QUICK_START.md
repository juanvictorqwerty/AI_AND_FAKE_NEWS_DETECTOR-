# Native Notification System - Quick Start Guide

## Overview

The notification system is now **fully native** and works **without Flutter**. It will start automatically when you first open the app.

## How It Works

### Automatic Startup
The service starts automatically in these scenarios:
1. **First app launch** - Service starts when you open the app for the first time
2. **Device boot** - Service starts when your device boots up
3. **App update** - Service restarts after app updates

### Manual Control (Optional)
You can also control the service manually from Flutter:

```dart
import 'package:flutter/services.dart';

const platform = MethodChannel('fact_check_channel');

// Start the service
await platform.invokeMethod('startNotificationService');

// Stop the service
await platform.invokeMethod('stopNotificationService');
```

## Configuration

### Step 1: Configure Base URL
The base URL should match your Flutter .env configuration:

```dart
// Get the base URL from your .env file
String baseUrl = dotenv.env['BASE_URL_NODE'] ?? 'http://192.168.1.152:4000';

// Configure the native service
await platform.invokeMethod('configureBaseUrl', {'baseUrl': baseUrl});
```

### Step 2: Configure Auth Token
After user login, pass the JWT token to the native service:

```dart
// After successful login
String token = response['token'];

// Configure the native service
await platform.invokeMethod('configureAuthToken', {'token': token});
```

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationConfig {
  static const platform = MethodChannel('fact_check_channel');
  
  static Future<void> initialize() async {
    // Configure base URL from .env
    String baseUrl = dotenv.env['BASE_URL_NODE'] ?? 'http://192.168.1.152:4000';
    await platform.invokeMethod('configureBaseUrl', {'baseUrl': baseUrl});
    
    // Start the service
    await platform.invokeMethod('startNotificationService');
  }
  
  static Future<void> onUserLogin(String token) async {
    // Configure auth token after login
    await platform.invokeMethod('configureAuthToken', {'token': token});
  }
}
```

## Usage

### From Notification Bar
1. Pull down notification shade
2. Find "AI Fact Checker" notification
3. Tap "Fact Check" button
4. Type your claim
5. Press send
6. Wait for response (updates in same notification)

### Continuous Chat
- After receiving a response, the input field remains active
- Type another question and send
- All Q&A pairs are shown in the notification

## Troubleshooting

### Service Not Starting
**Problem**: Notification doesn't appear
**Solution**: 
1. Open the app once (service starts automatically)
2. Check if FOREGROUND_SERVICE permission is granted
3. Restart the app

### API Calls Failing
**Problem**: "Error: Please log in to use fact-checking"
**Solution**:
1. Ensure you're logged in to the app
2. Check if auth token is configured
3. Verify base URL is correct

### Notification Not Updating
**Problem**: Notification shows "Processing" but no result
**Solution**:
1. Check internet connection
2. Verify API server is running
3. Check auth token is valid
4. Review logs for errors

## Testing

### Test Service Startup
```dart
// Check if service is running
bool isRunning = await platform.invokeMethod('isServiceRunning');
print('Service running: $isRunning');
```

### Test Configuration
```dart
// Configure and start
await platform.invokeMethod('configureBaseUrl', {
  'baseUrl': 'http://192.168.1.152:4000'
});
await platform.invokeMethod('configureAuthToken', {
  'token': 'your-test-token'
});
await platform.invokeMethod('startNotificationService');
```

## Key Features

✅ **No Flutter Required** - Works when app is closed
✅ **Auto-Start** - Starts automatically on boot/launch
✅ **Persistent** - Survives app closure
✅ **Efficient** - Native OkHttp for fast API calls
✅ **Reliable** - No Flutter engine crashes

## Architecture

```
┌─────────────────────────────────────┐
│  Notification Bar (User Input)      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  NotificationForegroundService      │
│  (Native Kotlin Service)            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  FactCheckApiService                │
│  (OkHttp + Coroutines)             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  External API                       │
│  (fact-check/search)                │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Notification Update                │
│  (Same notification, no new ones)   │
└─────────────────────────────────────┘
```

## Support

For detailed documentation, see:
- `NATIVE_NOTIFICATION_SYSTEM.md` - Complete implementation guide
- `NATIVE_REFACTORING_SUMMARY.md` - Technical details

## Summary

The native notification system is now ready to use. It will:
1. Start automatically when you open the app
2. Work independently of Flutter
3. Handle fact-checking requests natively
4. Update notifications efficiently

No additional setup required - just open the app and use it!
