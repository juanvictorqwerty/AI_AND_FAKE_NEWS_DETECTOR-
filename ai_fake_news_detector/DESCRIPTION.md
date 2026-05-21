# AI Fake News Detector - Mobile App

## Overview

The mobile application layer of the AI and Fake News Detector system. This is a cross-platform Flutter application that provides users with real-time fact-checking, image analysis, and media verification capabilities.

## Purpose

This application serves as the primary user interface for:
- **Real-time Fact Checking**: Verify claims and news articles instantly
- **Image Analysis**: Upload and analyze images for authenticity and AI-generated content detection
- **Video Upload**: Submit video files for comprehensive media analysis
- **Persistent Notifications**: Access quick fact-checking through a background notification service
- **Media Management**: Built-in media picker for easy image and video selection from device storage

## Key Features

### Quick Fact Check
- Text-based fact verification
- Instant results from backend analysis
- Search history and saved results

### Image Analysis
- Single or batch image upload
- Authenticity detection (real vs. AI-generated)
- Confidence scores and detailed analysis

### Video Support
- Video file upload and processing
- Thumbnail extraction
- Frame-by-frame analysis capabilities

### Persistent Notification Service
- Background fact-checking without app focus
- Quick-access notification interface
- Real-time fact-check requests from notification shade
- Stop/pause service controls

### Cross-Platform Support
- **Android**: Native Kotlin integration for notifications
- **iOS**: iOS-optimized interface and native features
- **Web**: Responsive web version for desktop browsers

## Technology Stack

| Technology | Purpose |
|-----------|---------|
| **Flutter 3.11+** | Cross-platform framework |
| **Dart** | Programming language |
| **GetX** | State management & routing |
| **http** | API communication |
| **image_picker** | Media selection |
| **video_player** | Video playback |
| **get_thumbnail_video** | Video thumbnail generation |
| **permission_handler** | Platform permissions |
| **shared_preferences** | Local storage |
| **Kotlin** | Android native code (notifications) |

## Project Structure

```
ai_fake_news_detector/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── screens/                  # UI screens
│   ├── widgets/                  # Reusable components
│   ├── services/                 # API & business logic
│   │   ├── notification_service.dart
│   │   ├── api_service.dart
│   │   └── media_service.dart
│   ├── models/                   # Data models
│   ├── controllers/              # State management
│   └── utils/                    # Helper functions
│
├── android/
│   └── app/src/main/
│       ├── kotlin/
│       │   └── NotificationForegroundService.kt
│       └── AndroidManifest.xml
│
├── ios/                          # iOS configuration
├── web/                          # Web build assets
├── test/                         # Unit & widget tests
├── assets/                       # Images, fonts, etc.
├── pubspec.yaml                  # Dependencies
└── env/                          # Environment configs
```

## Key Components

### Notification Service
- **File**: `lib/services/notification_service.dart`
- **Purpose**: Manages persistent background notification for quick access
- **Native Integration**: Communicates with Android's NotificationForegroundService via MethodChannel

### API Service
- **File**: `lib/services/api_service.dart`
- **Purpose**: Handles all HTTP communication with NestJS backend
- **Features**: 
  - Authentication token management
  - Request/response handling
  - Error management

### Media Service
- **File**: `lib/services/media_service.dart`
- **Purpose**: Manages image and video selection, upload, and processing
- **Features**:
  - Image picker integration
  - Video thumbnail generation
  - File validation

### State Management
- Uses **GetX** for reactive state management
- Controllers handle business logic and UI state
- Services layer for API communication

## Environment Configuration

Create `env.dev.json` with:
```json
{
  "api_url": "http://your-backend-url:3000",
  "analysis_service_url": "http://your-analysis-url:7860",
  "api_key": "your-api-key"
}
```

## Development Workflow

### Setup
```bash
flutter pub get
flutter pub upgrade
```

### Running
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d web
```

### Testing
```bash
flutter test
```

### Building
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Platform-Specific Notes

### Android
- Requires API level 21+
- Uses Kotlin for native notification service
- Permissions: READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE, INTERNET, POST_NOTIFICATIONS
- Notification service runs as foreground service

### iOS
- Requires iOS 12.0+
- Uses native Swift/Objective-C integration points
- App Transport Security configured for API communication

### Web
- Responsive design for desktop and tablet
- File handling via browser APIs
- Service worker for offline support

## Communication Flow

1. **User Action** → Flutter UI captures input (text/image/video)
2. **Local Processing** → Media picker, thumbnail generation, validation
3. **API Call** → HTTP request to NestJS backend
4. **Analysis** → Backend orchestrates with Python analysis service
5. **Response** → Results sent back to app
6. **Display** → Results shown in UI with visualizations

## Dependencies Management

```bash
# Check outdated packages
flutter pub outdated

# Upgrade packages
flutter pub upgrade

# Get specific version
flutter pub add package_name:version
```

## Troubleshooting

- **Build Issues**: Run `flutter clean && flutter pub get`
- **Hot Reload Issues**: Use `flutter run` with `-t` flag for specific file
- **Notification Issues**: Check Android service permissions and manifest configuration
- **Media Picker Issues**: Verify app permissions on device

## Next Steps for Development

1. Implement proper error handling and user feedback
2. Add offline capability with local caching
3. Implement result sharing functionality
4. Add analytics for user interactions
5. Optimize image/video upload performance
6. Implement advanced filtering and search

## Related Documentation

- [Build Instructions](./_docs/flutter/BUILD_INSTRUCTIONS.md)
- [Media Upload Implementation](./_docs/flutter/MEDIA_UPLOAD_IMPLEMENTATION_SUMMARY.md)
- [Notification System](./_docs/flutter/NATIVE_NOTIFICATION_SYSTEM.md)
- [Troubleshooting Guide](./_docs/flutter/TROUBLESHOOTING.md)

---

**Last Updated**: May 2026
**Version**: 1.0.0
