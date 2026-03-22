# Quick Settings Tile - Quick Reference Guide

## 🚀 Quick Start

### 1. Build and Install
```bash
cd ai_fake_news_detector
flutter clean
flutter build apk --release
flutter install
```

### 2. Add Tile to Quick Settings
1. Pull down notification shade
2. Tap edit icon (pencil)
3. Find "Fact Check" tile
4. Drag to active tiles
5. Tap to test!

## 📁 Files Created

### Android (Kotlin)
- [`QuickSettingsTileService.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/QuickSettingsTileService.kt) - Tile service
- [`OverlayActivity.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/OverlayActivity.kt) - Overlay host

### Android (Resources)
- [`ic_quick_settings_tile.xml`](ai_fake_news_detector/android/app/src/main/res/drawable/ic_quick_settings_tile.xml) - Tile icon
- [`quick_settings_tile.xml`](ai_fake_news_detector/android/app/src/main/res/xml/quick_settings_tile.xml) - Tile config

### Flutter (Dart)
- [`quick_settings_service.dart`](ai_fake_news_detector/lib/services/quick_settings_service.dart) - Service
- [`quick_settings_overlay.dart`](ai_fake_news_detector/lib/widgets/quick_settings_overlay.dart) - Overlay widget
- [`OverlayPage.dart`](ai_fake_news_detector/lib/pages/OverlayPage.dart) - Overlay page

### Documentation
- [`QUICK_SETTINGS_TILE_IMPLEMENTATION.md`](QUICK_SETTINGS_TILE_IMPLEMENTATION.md) - Full guide

## 🔧 Key Methods

### Flutter Service
```dart
// Get service instance
final service = Get.find<QuickSettingsService>();

// Check overlay permission
bool canDraw = await service.canDrawOverlays();

// Open overlay settings
await service.openOverlaySettings();

// Show overlay manually
service.showOverlay(
  triggerSource: 'Manual',
  message: 'Your message here',
);

// Update tile state
await service.updateTile();
```

### Android TileService
```kotlin
// Update tile appearance
private fun updateTile() {
    val tile = qsTile ?: return
    tile.label = "Fact Check"
    tile.state = Tile.STATE_INACTIVE
    tile.updateTile()
}

// Trigger overlay on click
override fun onClick() {
    super.onClick()
    val tile = qsTile
    tile?.state = Tile.STATE_ACTIVE
    tile?.updateTile()
    triggerFlutterOverlay()
}
```

## 🎨 Customization

### Change Tile Label
Edit [`QuickSettingsTileService.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/QuickSettingsTileService.kt:85):
```kotlin
tile.label = "Your Custom Label"
```

### Change Tile Icon
Replace [`ic_quick_settings_tile.xml`](ai_fake_news_detector/android/app/src/main/res/drawable/ic_quick_settings_tile.xml) with your custom icon.

### Customize Overlay
Edit [`quick_settings_overlay.dart`](ai_fake_news_detector/lib/widgets/quick_settings_overlay.dart):
- Change colors in `BoxDecoration`
- Modify text styles
- Add/remove buttons
- Adjust animations

## 🔐 Permissions Required

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

## 📱 Android Manifest Components

```xml
<!-- Quick Settings Tile Service -->
<service
    android:name=".QuickSettingsTileService"
    android:label="Fact Check"
    android:icon="@drawable/ic_quick_settings_tile"
    android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.service.quicksettings.action.QS_TILE" />
    </intent-filter>
    <meta-data
        android:name="android.service.quicksettings"
        android:resource="@xml/quick_settings_tile" />
</service>

<!-- Overlay Activity -->
<activity
    android:name=".OverlayActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/Theme.AppCompat.NoActionBar"
    android:excludeFromRecents="true">
</activity>
```

## 🔌 MethodChannel Names

```dart
// Flutter to Android
static const String _overlayChannel = 'com.example.ai_fake_news_detector/overlay';
static const String _quickSettingsChannel = 'com.example.ai_fake_news_detector/quick_settings';
```

## 🐛 Troubleshooting

### Tile Not Appearing
- ✅ Check Android version (requires API 24+)
- ✅ Verify manifest registration
- ✅ Clean and rebuild project
- ✅ Check logcat for errors

### Overlay Not Showing
- ✅ Grant SYSTEM_ALERT_WINDOW permission
- ✅ Verify OverlayActivity in manifest
- ✅ Check MethodChannel communication
- ✅ Review logcat logs

### MethodChannel Errors
- ✅ Verify channel names match
- ✅ Check method names spelling
- ✅ Ensure proper async/await
- ✅ Handle exceptions

## 📊 Architecture Flow

```
User taps tile
    ↓
QuickSettingsTileService.onClick()
    ↓
Launch OverlayActivity
    ↓
OverlayActivity.configureFlutterEngine()
    ↓
MethodChannel communication
    ↓
QuickSettingsService receives call
    ↓
Show QuickSettingsOverlay widget
    ↓
User interacts with overlay
    ↓
Close overlay via MethodChannel
```

## 🎯 Use Cases

1. **Quick Fact-Check**: Tap tile to instantly fact-check clipboard content
2. **Notification Check**: Verify recent notifications for fake news
3. **URL Verification**: Quick check URLs from clipboard
4. **Text Analysis**: Analyze selected text for misinformation

## 💡 Tips

1. **Keep overlay simple**: Users want quick results, not complex UI
2. **Handle errors gracefully**: Always catch MethodChannel exceptions
3. **Test thoroughly**: Test on different Android versions
4. **Monitor performance**: Watch for memory leaks with overlay engine
5. **User feedback**: Provide clear feedback for all actions

## 🔗 Related Files

- [`MainActivity.kt`](ai_fake_news_detector/android/app/src/main/kotlin/com/example/ai_fake_news_detector/MainActivity.kt) - Updated with MethodChannel
- [`AndroidManifest.xml`](ai_fake_news_detector/android/app/src/main/AndroidManifest.xml) - Updated with permissions
- [`main.dart`](ai_fake_news_detector/lib/main.dart) - Updated with service initialization

## 📞 Support

For issues or questions:
1. Check [`QUICK_SETTINGS_TILE_IMPLEMENTATION.md`](QUICK_SETTINGS_TILE_IMPLEMENTATION.md) for detailed guide
2. Review logcat for error messages
3. Verify all files are created correctly
4. Ensure permissions are granted

## ✅ Checklist

- [ ] All Android files created
- [ ] All Flutter files created
- [ ] AndroidManifest updated
- [ ] Permissions granted
- [ ] App built and installed
- [ ] Tile added to Quick Settings
- [ ] Tile click triggers overlay
- [ ] Overlay displays correctly
- [ ] Close button works
- [ ] Back button works
- [ ] Works with app closed

## 🎉 Success!

Your Quick Settings Tile is now ready to use! Users can:
- Add the tile to their Quick Settings
- Tap it anytime to trigger a fact-check overlay
- Use it even when the app is closed
- Enjoy a smooth, animated overlay experience
