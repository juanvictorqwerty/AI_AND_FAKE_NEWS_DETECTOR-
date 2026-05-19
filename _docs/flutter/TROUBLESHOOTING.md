# Troubleshooting: Notification Stops at "Processing"

## Problem
The notification shows "Processing: [text]" but nothing is sent to the backend.

## Root Cause
The MethodChannel communication from Kotlin to Flutter is not working properly.

## Debugging Steps

### 1. Check Flutter Logs
Run the app and check the console output for these messages:

**Expected logs:**
```
NotificationService: Setting up MethodChannel handler
NotificationService: MethodChannel received: onNotificationInput
NotificationService: onNotificationInput called with text: [your text]
NotificationService: ========== RECEIVED INPUT ==========
NotificationService: Text: [your text]
NotificationService: Auth token available: true
NotificationService: Calling fact check service...
```

**If you don't see these logs:**
- The MethodChannel handler is not set up
- The Flutter engine is not available in Kotlin

### 2. Check Android Logs
Use `adb logcat` to check Android logs:

```bash
adb logcat | grep -E "(NotificationForegroundService|NotificationService)"
```

**Expected logs:**
```
NotificationForegroundService: Sending to Flutter: [your text]
```

**If you see:**
```
NotificationForegroundService: ERROR - FlutterEngine is null
```

This means the FlutterEngine is not available when the service tries to send data.

### 3. Verify Service Initialization Order

The issue is likely that the MethodChannel handler is not set up before the service tries to use it.

**Check main.dart:**
```dart
// Set up MethodChannel before initializing NotificationService
NotificationService.setupChannel();
Get.put(NotificationService());
```

### 4. Check if FlutterEngine is Available

The FlutterEngine might not be available when the foreground service starts.

**In MainActivity.kt, verify:**
```kotlin
companion object {
    private var flutterEngineInstance: FlutterEngine? = null
    
    fun getFlutterEngine(): FlutterEngine? {
        return flutterEngineInstance
    }
}

override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngineInstance = flutterEngine
    // ... rest of code
}
```

## Solutions

### Solution 1: Ensure MethodChannel is Set Up Early

The MethodChannel handler must be set up before the service starts receiving messages.

**In main.dart:**
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: "assets/.env");

  // Initialize services
  Get.put(AuthService());
  Get.put(AuthController());
  Get.put(FactCheckService());
  
  // Set up MethodChannel BEFORE initializing NotificationService
  NotificationService.setupChannel();
  
  Get.put(NotificationService());
  
  runApp(const App());
}
```

### Solution 2: Add Error Handling

Add try-catch blocks to catch any errors:

**In notification_service.dart:**
```dart
static void setupChannel() {
  print('NotificationService: Setting up MethodChannel handler');
  try {
    _channel.setMethodCallHandler((MethodCall call) async {
      print('NotificationService: MethodChannel received: ${call.method}');
      try {
        switch (call.method) {
          case 'onNotificationInput':
            final String text = call.arguments as String;
            print('NotificationService: onNotificationInput called with text: $text');
            final instance = Get.find<NotificationService>();
            await instance._handleNotificationInput(text);
            break;
          default:
            print('NotificationService: Unknown method ${call.method}');
        }
      } catch (e) {
        print('NotificationService: Error in method handler: $e');
      }
    });
  } catch (e) {
    print('NotificationService: Error setting up channel: $e');
  }
}
```

### Solution 3: Verify FlutterEngine Availability

Add a check to ensure FlutterEngine is available:

**In NotificationForegroundService.kt:**
```kotlin
private fun sendToFlutter(text: String) {
    val flutterEngine = MainActivity.getFlutterEngine()
    if (flutterEngine != null) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fact_check_channel")
        println("NotificationForegroundService: Sending to Flutter: $text")
        try {
            channel.invokeMethod("onNotificationInput", text)
        } catch (e: Exception) {
            println("NotificationForegroundService: Error invoking method: $e")
        }
    } else {
        println("NotificationForegroundService: ERROR - FlutterEngine is null")
        // Update notification with error
        updateNotificationWithStatus("Error: Flutter not available")
    }
}
```

### Solution 4: Check Authentication Token

The API call might fail if the token is invalid:

**In notification_service.dart:**
```dart
Future<void> _handleNotificationInput(String text) async {
  print('NotificationService: ========== RECEIVED INPUT ==========');
  print('NotificationService: Text: $text');
  
  try {
    final token = _authController.token.value;
    print('NotificationService: Token length: ${token.length}');
    print('NotificationService: Token isEmpty: ${token.isEmpty}');
    
    if (token.isEmpty) {
      print('NotificationService: ERROR - No auth token available');
      await _updateNotificationResult('Error: Not authenticated. Please login first.');
      return;
    }
    
    print('NotificationService: Calling fact check service...');
    final result = await _factCheckService.searchFactCheck(
      claim: text,
      token: token,
    );
    print('NotificationService: Fact check result: $result');
    
    // ... rest of code
  } catch (e) {
    print('NotificationService: Error processing input: $e');
    await _updateNotificationResult('Error: ${e.toString()}');
  }
}
```

## Testing the Fix

### Step 1: Clean and Rebuild
```bash
cd ai_fake_news_detector
flutter clean
flutter pub get
flutter run
```

### Step 2: Check Logs
1. Open the app
2. Log in
3. Start the service
4. Enter text in notification
5. Check console output for logs

### Step 3: Verify MethodChannel Communication
Look for these logs:
- `NotificationService: Setting up MethodChannel handler`
- `NotificationService: MethodChannel received: onNotificationInput`
- `NotificationForegroundService: Sending to Flutter: [text]`

### Step 4: Verify API Call
Look for these logs:
- `NotificationService: Calling fact check service...`
- `NotificationService: Fact check result: [result]`

## Common Issues

### Issue 1: "FlutterEngine is null"
**Cause:** FlutterEngine not available when service starts
**Solution:** Ensure MainActivity is running before starting service

### Issue 2: "No auth token available"
**Cause:** User not logged in or token expired
**Solution:** Log in again before using the feature

### Issue 3: "MethodChannel received" not showing
**Cause:** MethodChannel handler not set up
**Solution:** Call `NotificationService.setupChannel()` in main.dart

### Issue 4: API call fails
**Cause:** Network issue or invalid token
**Solution:** Check network connectivity and token validity

## Quick Debug Checklist

- [ ] MethodChannel handler set up in main.dart
- [ ] FlutterEngine available in MainActivity
- [ ] User is logged in (token available)
- [ ] Network connectivity available
- [ ] Backend API is running
- [ ] Logs show MethodChannel communication
- [ ] Logs show API call attempt

## If Still Not Working

1. **Check AndroidManifest.xml** - Ensure service is declared
2. **Check permissions** - Ensure FOREGROUND_SERVICE permission granted
3. **Check build** - Clean and rebuild the project
4. **Check device** - Test on different device/emulator
5. **Check backend** - Verify API endpoint is accessible

## Contact Support

If the issue persists after trying all solutions:
1. Share the console logs
2. Share the Android logs (adb logcat)
3. Share the device/emulator details
4. Share the Flutter version
