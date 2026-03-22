# Android Quick Settings Tile Implementation Guide

This guide provides a complete implementation of an Android Quick Settings Tile for your Flutter app that can trigger an overlay popup even when the app is closed.

## Overview

The implementation consists of:
1. **Android Native Components** (Kotlin)
   - `QuickSettingsTileService` - Manages the Quick Settings tile
   - `OverlayActivity` - Hosts the Flutter overlay popup
   - AndroidManifest configuration
   - Tile icon resources

2. **Flutter Components** (Dart)
   - `QuickSettingsOverlay` - The overlay popup widget
   - `QuickSettingsService` - MethodChannel communication handler
   - `OverlayPage` - Dedicated page for overlay activity

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Android System                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Quick Settings Tile Service                  │  │
│  │  - Runs independently                                │  │
│  │  - Handles tile clicks                               │  │
│  │  - Launches OverlayActivity                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           OverlayActivity                            │  │
│  │  - Displays as overlay                               │  │
│  │  - Hosts Flutter engine                              │  │
│  │  - Communicates via MethodChannel                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         QuickSettingsService                         │  │
│  │  - Manages MethodChannel communication               │  │
│  │  - Handles overlay display logic                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         QuickSettingsOverlay Widget                  │  │
│  │  - Beautiful popup UI                                │  │
│  │  - Displays fact-check results                       │  │
│  │  - Animations and interactions                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```
ai_fake_news_detector/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── kotlin/com/example/ai_fake_news_detector/
│               │   ├── MainActivity.kt (updated)
│               │   ├── QuickSettingsTileService.kt (new)
│               │   └── OverlayActivity.kt (new)
│               ├── res/
│               │   ├── drawable/
│               │   │   └── ic_quick_settings_tile.xml (new)
│               │   └── xml/
│               │       └── quick_settings_tile.xml (new)
│               └── AndroidManifest.xml (updated)
└── lib/
    ├── main.dart (updated)
    ├── services/
    │   └── quick_settings_service.dart (new)
    ├── widgets/
    │   └── quick_settings_overlay.dart (new)
    └── pages/
        └── OverlayPage.dart (new)
```

## Implementation Details

### 1. Android Native Components

#### QuickSettingsTileService.kt

This service manages the Quick Settings tile lifecycle:

- **onTileAdded()**: Called when tile is added to Quick Settings
- **onStartListening()**: Called when tile becomes visible
- **onClick()**: Called when user clicks the tile - triggers overlay
- **updateTile()**: Updates tile appearance and state

Key features:
- Runs independently of the main app
- Can trigger overlay even when app is closed
- Manages tile state (active/inactive)
- Launches OverlayActivity on click

#### OverlayActivity.kt

This activity hosts the Flutter overlay:

- Configures window as overlay (TYPE_APPLICATION_OVERLAY)
- Handles overlay permissions
- Communicates with Flutter via MethodChannel
- Provides close functionality

Key features:
- Displays as system overlay
- Semi-transparent background
- Handles back button to close
- Manages permission requests

#### AndroidManifest.xml

Required permissions and components:

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>

<service
    android:name=".QuickSettingsTileService"
    android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.service.quicksettings.action.QS_TILE" />
    </intent-filter>
    <meta-data
        android:name="android.service.quicksettings"
        android:resource="@xml/quick_settings_tile" />
</service>

<activity
    android:name=".OverlayActivity"
    android:theme="@style/Theme.AppCompat.NoActionBar"
    android:excludeFromRecents="true">
</activity>
```

### 2. Flutter Components

#### QuickSettingsService

Manages MethodChannel communication:

```dart
class QuickSettingsService extends GetxService {
  // Channels
  static const String _overlayChannel = 'com.example.ai_fake_news_detector/overlay';
  static const String _quickSettingsChannel = 'com.example.ai_fake_news_detector/quick_settings';
  
  // Methods
  Future<bool> canDrawOverlays()
  Future<void> openOverlaySettings()
  Future<void> updateTile()
  void showOverlay({String? triggerSource, String? message})
}
```

#### QuickSettingsOverlay Widget

Beautiful popup UI with:
- Animated entrance (fade + slide)
- Header with icon and close button
- Content area for messages
- Action buttons (Close, Open App)
- Semi-transparent background

#### OverlayPage

Dedicated page for overlay activity:
- Loads trigger source from Android
- Displays QuickSettingsOverlay
- Handles MethodChannel communication

## Setup Instructions

### Step 1: Android Configuration

1. **Add permissions to AndroidManifest.xml**:
   ```xml
   <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
   <uses-permission android:name="android.permission.WAKE_LOCK"/>
   ```

2. **Register QuickSettingsTileService**:
   ```xml
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
   ```

3. **Register OverlayActivity**:
   ```xml
   <activity
       android:name=".OverlayActivity"
       android:exported="true"
       android:launchMode="singleTop"
       android:theme="@style/Theme.AppCompat.NoActionBar"
       android:excludeFromRecents="true">
   </activity>
   ```

### Step 2: Flutter Configuration

1. **Initialize QuickSettingsService in main.dart**:
   ```dart
   import 'package:ai_fake_news_detector/services/quick_settings_service.dart';
   
   void main() async {
     // ... existing code ...
     Get.put(QuickSettingsService());
     runApp(const App());
   }
   ```

2. **Use the service in your app**:
   ```dart
   final quickSettingsService = Get.find<QuickSettingsService>();
   
   // Check overlay permission
   bool canDraw = await quickSettingsService.canDrawOverlays();
   
   // Open overlay settings
   await quickSettingsService.openOverlaySettings();
   
   // Show overlay manually
   quickSettingsService.showOverlay(
     triggerSource: 'Manual',
     message: 'Custom message here',
   );
   ```

### Step 3: Testing

1. **Build and install the app**:
   ```bash
   flutter build apk --release
   flutter install
   ```

2. **Add tile to Quick Settings**:
   - Pull down notification shade
   - Tap edit icon (pencil)
   - Find "Fact Check" tile
   - Drag to active tiles

3. **Test the tile**:
   - Tap the tile
   - Overlay should appear
   - Test close functionality
   - Test with app closed

## Usage Examples

### Show Overlay from Flutter Code

```dart
import 'package:ai_fake_news_detector/services/quick_settings_service.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final service = Get.find<QuickSettingsService>();
        service.showOverlay(
          triggerSource: 'Button Click',
          message: 'Fact-check initiated from app!',
        );
      },
      child: Text('Show Overlay'),
    );
  }
}
```

### Check and Request Overlay Permission

```dart
Future<void> checkOverlayPermission() async {
  final service = Get.find<QuickSettingsService>();
  
  bool canDraw = await service.canDrawOverlays();
  
  if (!canDraw) {
    // Show dialog explaining why permission is needed
    Get.dialog(
      AlertDialog(
        title: Text('Overlay Permission Required'),
        content: Text('Please grant overlay permission to use Quick Settings tile'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await service.openOverlaySettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
```

### Update Tile State

```dart
Future<void> updateTileFromFlutter() async {
  final service = Get.find<QuickSettingsService>();
  await service.updateTile();
}
```

## Troubleshooting

### Tile Not Appearing

1. **Check Android version**: Quick Settings tiles require Android 7.0 (API 24)+
2. **Verify manifest**: Ensure service is properly registered
3. **Check permissions**: BIND_QUICK_SETTINGS_TILE permission is required
4. **Rebuild app**: Clean and rebuild after manifest changes

### Overlay Not Showing

1. **Check SYSTEM_ALERT_WINDOW permission**: Must be granted
2. **Verify OverlayActivity**: Ensure it's registered in manifest
3. **Check logs**: Look for errors in logcat
4. **Test permission**: Use `canDrawOverlays()` method

### MethodChannel Errors

1. **Channel names**: Ensure channel names match between Android and Flutter
2. **Method names**: Verify method names are spelled correctly
3. **Arguments**: Check argument types and names
4. **Async handling**: Ensure proper async/await usage

### Overlay Not Closing

1. **Back button**: Ensure onBackPressed() is implemented
2. **Close method**: Verify closeOverlay() is called
3. **Activity finish**: Check finish() is called properly

## Advanced Customization

### Custom Tile Icon

Replace `ic_quick_settings_tile.xml` with your custom icon:

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <!-- Your custom icon path data -->
</vector>
```

### Custom Overlay Design

Modify `QuickSettingsOverlay` widget:
- Change colors and styling
- Add custom content
- Modify animations
- Add additional buttons

### Multiple Tiles

To add multiple tiles:

1. Create additional TileService classes
2. Register them in AndroidManifest.xml
3. Create corresponding XML configurations
4. Handle different tile IDs in onClick()

## Performance Considerations

1. **Memory**: OverlayActivity creates a new Flutter engine instance
2. **Battery**: Tile service runs in background
3. **Startup time**: First overlay may have slight delay
4. **Cleanup**: Properly dispose of resources

## Security Considerations

1. **Overlay permission**: User must explicitly grant
2. **Activity isolation**: OverlayActivity is separate from main app
3. **Data handling**: Be careful with sensitive data in overlays
4. **Permission scope**: Only request necessary permissions

## Best Practices

1. **User experience**: Keep overlay simple and quick
2. **Error handling**: Always handle MethodChannel exceptions
3. **Logging**: Use debug prints for troubleshooting
4. **Testing**: Test on multiple Android versions
5. **Documentation**: Keep this guide updated

## References

- [Android Quick Settings Tiles](https://developer.android.com/reference/android/service/quicksettings/TileService)
- [Android System Alert Window](https://developer.android.com/reference/android/Manifest.permission#SYSTEM_ALERT_WINDOW)
- [Flutter MethodChannel](https://docs.flutter.dev/platform-integration/platform-channels)
- [Flutter Platform Views](https://docs.flutter.dev/platform-integration/android/platform-views)

## License

This implementation is provided as-is for educational purposes.
