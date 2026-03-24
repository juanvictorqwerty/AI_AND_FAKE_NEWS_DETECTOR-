# Build Instructions

## Important: R Class Generation

The errors you're seeing (Unresolved reference: ic_send, ic_close) are expected because the R class hasn't been regenerated yet after adding the new drawable resources. These errors will be resolved once you build the project.

## Steps to Build

### 1. Clean the Project
```bash
cd ai_fake_news_detector
flutter clean
```

### 2. Get Dependencies
```bash
flutter pub get
```

### 3. Build for Android
```bash
flutter build apk
```

Or run directly:
```bash
flutter run
```

## What Happens During Build

1. **R Class Generation**: Android build system generates the R class which includes references to all resources (drawables, strings, layouts, etc.)

2. **Resource Compilation**: The drawable XML files (ic_send.xml, ic_close.xml) are compiled into the APK

3. **Kotlin Compilation**: The Kotlin code is compiled with the generated R class

## Expected Errors Before Build

You may see these errors in your IDE before building:
- `Unresolved reference: ic_send`
- `Unresolved reference: ic_close`
- `Unresolved reference: getFlutterEngine`

These are **normal** and will be resolved after building.

## After Building

Once the build completes successfully:
1. The R class will include references to ic_send and ic_close
2. The getFlutterEngine method will be recognized
3. All code will compile without errors

## Running the App

### On Emulator
```bash
flutter run
```

### On Physical Device
```bash
flutter run -d <device-id>
```

### Build Release APK
```bash
flutter build apk --release
```

## Troubleshooting

### If Build Fails

1. **Clean again**:
   ```bash
   flutter clean
   rm -rf build/
   rm -rf .dart_tool/
   flutter pub get
   ```

2. **Check Android SDK**:
   - Ensure Android SDK is properly configured
   - Check that you have the required SDK versions installed

3. **Check Gradle**:
   - Ensure Gradle is properly configured
   - Try running `./gradlew clean` in the android directory

### If Errors Persist

1. **Invalidate caches in Android Studio**:
   - File → Invalidate Caches / Restart

2. **Reimport project**:
   - Close the project
   - Reimport it fresh

3. **Check file locations**:
   - Verify ic_send.xml is in `android/app/src/main/res/drawable/`
   - Verify ic_close.xml is in `android/app/src/main/res/drawable/`

## File Structure Verification

Ensure these files exist:
```
ai_fake_news_detector/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── res/
│               │   └── drawable/
│               │       ├── ic_send.xml ✓
│               │       └── ic_close.xml ✓
│               └── kotlin/
│                   └── com/
│                       └── example/
│                           └── ai_fake_news_detector/
│                               ├── MainActivity.kt ✓
│                               └── NotificationForegroundService.kt ✓
└── lib/
    └── services/
        └── notification_service.dart ✓
```

## Next Steps After Build

1. **Test the feature**:
   - Open the app
   - Log in
   - Tap "Start Service"
   - Pull down notification shade
   - Test the text input

2. **Verify functionality**:
   - Notification appears
   - Text input works
   - Fact check button works
   - Results appear in notification
   - Stop button works

## Support

If you encounter issues after building:
1. Check the Android logs: `adb logcat`
2. Verify all files are in the correct locations
3. Ensure permissions are granted (especially POST_NOTIFICATIONS on Android 13+)
