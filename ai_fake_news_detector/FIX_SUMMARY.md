# Fix Summary: NullPointerException in Notification Update

## Problem
When Flutter tried to update the notification with results, it was throwing a NullPointerException:

```
java.lang.NullPointerException: Attempt to invoke virtual method 'android.content.res.Resources android.content.Context.getResources()' on a null object reference
      at android.content.ContextWrapper.getResources(ContextWrapper.java:101)
      at android.app.Notification$Builder.<init>(Notification.java:3642)
```

## Root Cause
In [`MainActivity.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MainActivity.kt:100), when Flutter called `updateNotificationResult`, the code was creating a **new instance** of `NotificationForegroundService`:

```kotlin
val service = NotificationForegroundService()  // ❌ Creates new instance
service.updateNotificationWithResult(resultText)
```

This new instance didn't have a valid Android Context, causing the NullPointerException when trying to build the notification.

## Solution
Modified the code to use the **running service instance** instead of creating a new one:

### 1. Added Static Instance Reference in NotificationForegroundService

**File:** [`NotificationForegroundService.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/NotificationForegroundService.kt)

```kotlin
companion object {
    // ... existing constants ...
    private var instance: NotificationForegroundService? = null
    
    fun getInstance(): NotificationForegroundService? {
        return instance
    }
}
```

### 2. Set Instance in onCreate

```kotlin
override fun onCreate() {
    super.onCreate()
    instance = this  // ✅ Store reference to running instance
    createNotificationChannel()
}
```

### 3. Clear Instance in onDestroy

```kotlin
override fun onDestroy() {
    super.onDestroy()
    instance = null  // ✅ Clear reference when service stops
    isRunning = false
}
```

### 4. Use getInstance() in MainActivity

**File:** [`MainActivity.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MainActivity.kt:96)

```kotlin
"updateNotificationResult" -> {
    val resultText = call.argument<String>("result")
    if (resultText != null) {
        // ✅ Use running service instance instead of creating new one
        val service = NotificationForegroundService.getInstance()
        if (service != null) {
            service.updateNotificationWithResult(resultText)
        } else {
            println("MainActivity: ERROR - NotificationForegroundService instance is null")
        }
    }
    result.success(true)
}
```

## How It Works Now

### Before (Broken)
```
Flutter calls updateNotificationResult
    ↓
MainActivity creates new NotificationForegroundService()  ❌
    ↓
New instance has no Context
    ↓
NullPointerException when building notification
```

### After (Fixed)
```
Flutter calls updateNotificationResult
    ↓
MainActivity gets running instance via getInstance()  ✅
    ↓
Running instance has valid Context
    ↓
Notification updates successfully
```

## Data Flow

1. **User enters text** in notification
2. **Kotlin service** receives text via RemoteInput
3. **Kotlin service** sends text to Flutter via MethodChannel
4. **Flutter** processes text and calls API
5. **Flutter** sends result back to Kotlin via MethodChannel
6. **MainActivity** gets running service instance via `getInstance()`
7. **Running service** updates notification with result

## Files Modified

1. [`NotificationForegroundService.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/NotificationForegroundService.kt)
   - Added `instance` variable in companion object
   - Added `getInstance()` method
   - Set `instance = this` in `onCreate()`
   - Set `instance = null` in `onDestroy()`

2. [`MainActivity.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MainActivity.kt)
   - Changed from `NotificationForegroundService()` to `NotificationForegroundService.getInstance()`
   - Added null check and error logging

## Testing

After rebuilding the app:

1. **Start the service** from the app
2. **Enter text** in notification
3. **Tap "Fact Check"**
4. **Check logs** for:
   - `NotificationService: Calling fact check service...`
   - `NotificationService: Fact check result: [result]`
   - No NullPointerException errors

## Expected Behavior

- ✅ Notification updates with result
- ✅ No NullPointerException
- ✅ Service continues running
- ✅ Can enter more text and get more results

## Additional Notes

The `ic_send` and `ic_close` errors are still expected and will be resolved after building the project (see [`EXPECTED_ERRORS.md`](ai_fake_news_detector/EXPECTED_ERRORS.md)).
