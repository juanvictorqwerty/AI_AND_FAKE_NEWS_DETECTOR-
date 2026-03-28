import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

/// Service for picking and validating media files (images and videos)
/// 
/// This service handles:
/// - File picking from gallery
/// - Robust permission handling across Android versions
/// - File size validation (max 20MB)
/// - Video duration validation (max 60 seconds)
/// - Returning validated file paths
class MediaPickerService extends GetxService {
  final ImagePicker _picker = ImagePicker();
  
  // Validation constants
  static const int maxFileSizeBytes = 20 * 1024 * 1024; // 20MB
  static const int maxVideoDurationSeconds = 60; // 60 seconds
  
  // Cache permission status to avoid repeated checks
  bool? _hasMediaPermission;
  
  /// Check and request media permissions with robust handling
  /// 
  /// Returns a Map with:
  /// - 'granted': bool indicating if permission is granted
  /// - 'message': error or info message
  /// - 'permanentlyDenied': bool indicating if permission is permanently denied
  Future<Map<String, dynamic>> checkAndRequestMediaPermissions() async {
    try {
      // Log permission check start
      debugPrint('MediaPickerService: Checking media permissions...');
      
      // Check if we already have permission cached
      if (_hasMediaPermission == true) {
        debugPrint('MediaPickerService: Permission already granted (cached)');
        return {'granted': true, 'message': 'Permission already granted'};
      }
      
      // Determine which permissions to request based on platform
      if (Platform.isAndroid) {
        return await _handleAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _handleIOSPermissions();
      } else {
        debugPrint('MediaPickerService: Unsupported platform');
        return {
          'granted': false,
          'message': 'Unsupported platform for media permissions',
        };
      }
    } catch (e) {
      debugPrint('MediaPickerService: Error checking permissions: $e');
      return {
        'granted': false,
        'message': 'Error checking permissions: ${e.toString()}',
      };
    }
  }
  
  /// Handle Android permissions with version detection
  /// 
  /// Android 13+ (API 33+): READ_MEDIA_IMAGES and READ_MEDIA_VIDEO
  /// Android ≤12: READ_EXTERNAL_STORAGE
  Future<Map<String, dynamic>> _handleAndroidPermissions() async {
    try {
      // Check current permission status
      PermissionStatus? imageStatus;
      PermissionStatus? videoStatus;
      PermissionStatus? storageStatus;
      
      // Try to check Android 13+ permissions first
      try {
        imageStatus = await Permission.photos.status;
        videoStatus = await Permission.videos.status;
        debugPrint('MediaPickerService: Android 13+ permissions - Photos: $imageStatus, Videos: $videoStatus');
      } catch (e) {
        debugPrint('MediaPickerService: Android 13+ permissions not available, trying storage permission');
      }
      
      // Check storage permission for older Android versions
      try {
        storageStatus = await Permission.storage.status;
        debugPrint('MediaPickerService: Storage permission status: $storageStatus');
      } catch (e) {
        debugPrint('MediaPickerService: Storage permission not available');
      }
      
      // Determine which permission strategy to use
      bool hasPermission = false;
      bool isPermanentlyDenied = false;
      String permissionType = '';
      
      // Strategy 1: Check if Android 13+ permissions are granted
      if (imageStatus != null && videoStatus != null) {
        if (imageStatus.isGranted && videoStatus.isGranted) {
          hasPermission = true;
          permissionType = 'Android 13+ (Photos & Videos)';
          debugPrint('MediaPickerService: Android 13+ permissions already granted');
        } else if (imageStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied) {
          isPermanentlyDenied = true;
          permissionType = 'Android 13+ (Permanently Denied)';
          debugPrint('MediaPickerService: Android 13+ permissions permanently denied');
        }
      }
      
      // Strategy 2: Check if storage permission is granted (for older Android)
      if (!hasPermission && storageStatus != null) {
        if (storageStatus.isGranted) {
          hasPermission = true;
          permissionType = 'Storage (Android ≤12)';
          debugPrint('MediaPickerService: Storage permission already granted');
        } else if (storageStatus.isPermanentlyDenied) {
          isPermanentlyDenied = true;
          permissionType = 'Storage (Permanently Denied)';
          debugPrint('MediaPickerService: Storage permission permanently denied');
        }
      }
      
      // If permission is already granted, cache and return
      if (hasPermission) {
        _hasMediaPermission = true;
        return {
          'granted': true,
          'message': 'Permission granted ($permissionType)',
        };
      }
      
      // If permanently denied, guide user to settings
      if (isPermanentlyDenied) {
        return {
          'granted': false,
          'message': 'Permission permanently denied. Please enable in app settings.',
          'permanentlyDenied': true,
        };
      }
      
      // Request permissions
      debugPrint('MediaPickerService: Requesting permissions...');
      
      // Try Android 13+ permissions first
      if (imageStatus != null && videoStatus != null) {
        debugPrint('MediaPickerService: Requesting Android 13+ permissions...');
        final newImageStatus = await Permission.photos.request();
        final newVideoStatus = await Permission.videos.request();
        
        debugPrint('MediaPickerService: Android 13+ request results - Photos: $newImageStatus, Videos: $newVideoStatus');
        
        if (newImageStatus.isGranted && newVideoStatus.isGranted) {
          _hasMediaPermission = true;
          return {
            'granted': true,
            'message': 'Permission granted (Android 13+)',
          };
        } else if (newImageStatus.isPermanentlyDenied || newVideoStatus.isPermanentlyDenied) {
          return {
            'granted': false,
            'message': 'Permission permanently denied. Please enable in app settings.',
            'permanentlyDenied': true,
          };
        } else {
          return {
            'granted': false,
            'message': 'Permission denied. Storage permission is required to access gallery.',
          };
        }
      }
      
      // Fallback to storage permission for older Android
      if (storageStatus != null) {
        debugPrint('MediaPickerService: Requesting storage permission...');
        final newStorageStatus = await Permission.storage.request();
        
        debugPrint('MediaPickerService: Storage request result: $newStorageStatus');
        
        if (newStorageStatus.isGranted) {
          _hasMediaPermission = true;
          return {
            'granted': true,
            'message': 'Permission granted (Storage)',
          };
        } else if (newStorageStatus.isPermanentlyDenied) {
          return {
            'granted': false,
            'message': 'Permission permanently denied. Please enable in app settings.',
            'permanentlyDenied': true,
          };
        } else {
          return {
            'granted': false,
            'message': 'Permission denied. Storage permission is required to access gallery.',
          };
        }
      }
      
      // If no permission strategy worked
      return {
        'granted': false,
        'message': 'Unable to request media permissions. Please check app settings.',
      };
    } catch (e) {
      debugPrint('MediaPickerService: Error handling Android permissions: $e');
      return {
        'granted': false,
        'message': 'Error handling permissions: ${e.toString()}',
      };
    }
  }
  
  /// Handle iOS permissions
  Future<Map<String, dynamic>> _handleIOSPermissions() async {
    try {
      debugPrint('MediaPickerService: Checking iOS photo library permission...');
      
      final status = await Permission.photos.status;
      debugPrint('MediaPickerService: iOS photo library status: $status');
      
      if (status.isGranted) {
        _hasMediaPermission = true;
        return {
          'granted': true,
          'message': 'Photo library permission granted',
        };
      }
      
      if (status.isPermanentlyDenied) {
        return {
          'granted': false,
          'message': 'Photo library permission permanently denied. Please enable in app settings.',
          'permanentlyDenied': true,
        };
      }
      
      // Request permission
      debugPrint('MediaPickerService: Requesting iOS photo library permission...');
      final newStatus = await Permission.photos.request();
      debugPrint('MediaPickerService: iOS photo library request result: $newStatus');
      
      if (newStatus.isGranted) {
        _hasMediaPermission = true;
        return {
          'granted': true,
          'message': 'Photo library permission granted',
        };
      } else if (newStatus.isPermanentlyDenied) {
        return {
          'granted': false,
          'message': 'Photo library permission permanently denied. Please enable in app settings.',
          'permanentlyDenied': true,
        };
      } else {
        return {
          'granted': false,
          'message': 'Photo library permission denied. Permission is required to access gallery.',
        };
      }
    } catch (e) {
      debugPrint('MediaPickerService: Error handling iOS permissions: $e');
      return {
        'granted': false,
        'message': 'Error handling permissions: ${e.toString()}',
      };
    }
  }
  
  /// Open app settings for permission management
  /// 
  /// Returns true if settings were opened successfully
  Future<bool> openAppSettings() async {
    try {
      debugPrint('MediaPickerService: Opening app settings...');
      final opened = await openAppSettings();
      debugPrint('MediaPickerService: App settings opened: $opened');
      return opened;
    } catch (e) {
      debugPrint('MediaPickerService: Error opening app settings: $e');
      return false;
    }
  }
  
  /// Reset cached permission status
  /// 
  /// Useful when user changes permissions in settings
  void resetPermissionCache() {
    debugPrint('MediaPickerService: Resetting permission cache');
    _hasMediaPermission = null;
  }
  
  /// Pick an image from gallery with validation
  /// 
  /// Returns a Map with:
  /// - 'success': bool indicating if operation was successful
  /// - 'filePath': path to the validated file (if successful)
  /// - 'message': error message (if unsuccessful)
  /// - 'permanentlyDenied': bool indicating if permission is permanently denied
  Future<Map<String, dynamic>> pickImage() async {
    try {
      // Check and request permissions first
      final permissionResult = await checkAndRequestMediaPermissions();
      
      if (!permissionResult['granted']) {
        return {
          'success': false,
          'message': permissionResult['message'],
          'permanentlyDenied': permissionResult['permanentlyDenied'] ?? false,
        };
      }
      
      debugPrint('MediaPickerService: Picking image from gallery...');
      
      // Pick image from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Keep original quality
      );
      
      if (image == null) {
        debugPrint('MediaPickerService: No image selected');
        return {
          'success': false,
          'message': 'No image selected',
        };
      }
      
      debugPrint('MediaPickerService: Image selected: ${image.path}');
      
      // Validate file size
      final file = File(image.path);
      final fileSize = await file.length();
      
      debugPrint('MediaPickerService: Image file size: $fileSize bytes');
      
      if (fileSize > maxFileSizeBytes) {
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        debugPrint('MediaPickerService: Image too large: ${fileSizeMB}MB');
        return {
          'success': false,
          'message': 'Image must be less than 20MB (current: ${fileSizeMB}MB)',
        };
      }
      
      debugPrint('MediaPickerService: Image validation successful');
      return {
        'success': true,
        'filePath': image.path,
        'fileSize': fileSize,
        'fileType': 'image',
      };
    } catch (e) {
      debugPrint('MediaPickerService: Error picking image: $e');
      return {
        'success': false,
        'message': 'Error picking image: ${e.toString()}',
      };
    }
  }
  
  /// Pick a video from gallery with validation
  /// 
  /// Returns a Map with:
  /// - 'success': bool indicating if operation was successful
  /// - 'filePath': path to the validated file (if successful)
  /// - 'message': error message (if unsuccessful)
  /// - 'permanentlyDenied': bool indicating if permission is permanently denied
  Future<Map<String, dynamic>> pickVideo() async {
    try {
      // Check and request permissions first
      final permissionResult = await checkAndRequestMediaPermissions();
      
      if (!permissionResult['granted']) {
        return {
          'success': false,
          'message': permissionResult['message'],
          'permanentlyDenied': permissionResult['permanentlyDenied'] ?? false,
        };
      }
      
      debugPrint('MediaPickerService: Picking video from gallery...');
      
      // Pick video from gallery
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: maxVideoDurationSeconds),
      );
      
      if (video == null) {
        debugPrint('MediaPickerService: No video selected');
        return {
          'success': false,
          'message': 'No video selected',
        };
      }
      
      debugPrint('MediaPickerService: Video selected: ${video.path}');
      
      // Validate file size
      final file = File(video.path);
      final fileSize = await file.length();
      
      debugPrint('MediaPickerService: Video file size: $fileSize bytes');
      
      if (fileSize > maxFileSizeBytes) {
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        debugPrint('MediaPickerService: Video too large: ${fileSizeMB}MB');
        return {
          'success': false,
          'message': 'Video must be less than 20MB (current: ${fileSizeMB}MB)',
        };
      }
      
      // Validate video duration
      debugPrint('MediaPickerService: Validating video duration...');
      final durationResult = await _validateVideoDuration(video.path);
      if (!durationResult['success']) {
        return durationResult;
      }
      
      debugPrint('MediaPickerService: Video validation successful');
      return {
        'success': true,
        'filePath': video.path,
        'fileSize': fileSize,
        'fileType': 'video',
        'duration': durationResult['duration'],
      };
    } catch (e) {
      debugPrint('MediaPickerService: Error picking video: $e');
      return {
        'success': false,
        'message': 'Error picking video: ${e.toString()}',
      };
    }
  }
  
  /// Pick either image or video from gallery with validation
  /// 
  /// Returns a Map with:
  /// - 'success': bool indicating if operation was successful
  /// - 'filePath': path to the validated file (if successful)
  /// - 'fileType': 'image' or 'video' (if successful)
  /// - 'message': error message (if unsuccessful)
  /// - 'permanentlyDenied': bool indicating if permission is permanently denied
  Future<Map<String, dynamic>> pickMedia() async {
    try {
      // Check and request permissions first
      final permissionResult = await checkAndRequestMediaPermissions();
      
      if (!permissionResult['granted']) {
        return {
          'success': false,
          'message': permissionResult['message'],
          'permanentlyDenied': permissionResult['permanentlyDenied'] ?? false,
        };
      }
      
      debugPrint('MediaPickerService: Picking media from gallery...');
      
      // Pick media from gallery (allows both images and videos)
      final XFile? media = await _picker.pickMedia();
      
      if (media == null) {
        debugPrint('MediaPickerService: No media selected');
        return {
          'success': false,
          'message': 'No file selected',
        };
      }
      
      debugPrint('MediaPickerService: Media selected: ${media.path}');
      
      // Determine file type
      final isVideo = media.path.toLowerCase().endsWith('.mp4') ||
                      media.path.toLowerCase().endsWith('.mov') ||
                      media.path.toLowerCase().endsWith('.avi') ||
                      media.path.toLowerCase().endsWith('.mkv');
      
      debugPrint('MediaPickerService: Media type: ${isVideo ? 'video' : 'image'}');
      
      // Validate file size
      final file = File(media.path);
      final fileSize = await file.length();
      
      debugPrint('MediaPickerService: Media file size: $fileSize bytes');
      
      if (fileSize > maxFileSizeBytes) {
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        debugPrint('MediaPickerService: Media too large: ${fileSizeMB}MB');
        return {
          'success': false,
          'message': 'File must be less than 20MB (current: ${fileSizeMB}MB)',
        };
      }
      
      // If video, validate duration
      if (isVideo) {
        debugPrint('MediaPickerService: Validating video duration...');
        final durationResult = await _validateVideoDuration(media.path);
        if (!durationResult['success']) {
          return durationResult;
        }
        
        debugPrint('MediaPickerService: Video validation successful');
        return {
          'success': true,
          'filePath': media.path,
          'fileSize': fileSize,
          'fileType': 'video',
          'duration': durationResult['duration'],
        };
      }
      
      debugPrint('MediaPickerService: Image validation successful');
      return {
        'success': true,
        'filePath': media.path,
        'fileSize': fileSize,
        'fileType': 'image',
      };
    } catch (e) {
      debugPrint('MediaPickerService: Error picking media: $e');
      return {
        'success': false,
        'message': 'Error picking media: ${e.toString()}',
      };
    }
  }
  
  /// Validate video duration
  /// 
  /// Returns a Map with:
  /// - 'success': bool indicating if validation passed
  /// - 'duration': video duration in seconds (if successful)
  /// - 'message': error message (if unsuccessful)
  Future<Map<String, dynamic>> _validateVideoDuration(String videoPath) async {
    VideoPlayerController? controller;
    try {
      debugPrint('MediaPickerService: Initializing video controller for duration check...');
      controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      
      final duration = controller.value.duration;
      final durationSeconds = duration.inSeconds;
      
      debugPrint('MediaPickerService: Video duration: $durationSeconds seconds');
      
      if (durationSeconds > maxVideoDurationSeconds) {
        debugPrint('MediaPickerService: Video too long: ${durationSeconds}s');
        return {
          'success': false,
          'message': 'Video must be under 60 seconds (current: ${durationSeconds}s)',
        };
      }
      
      debugPrint('MediaPickerService: Video duration validation passed');
      return {
        'success': true,
        'duration': durationSeconds,
      };
    } catch (e) {
      debugPrint('MediaPickerService: Error validating video duration: $e');
      return {
        'success': false,
        'message': 'Error validating video: ${e.toString()}',
      };
    } finally {
      // Clean up controller to free memory
      if (controller != null) {
        debugPrint('MediaPickerService: Disposing video controller...');
        await controller.dispose();
      }
    }
  }
  
  /// Get file size in human-readable format
  /// 
  /// [bytes] - file size in bytes
  /// Returns formatted string (e.g., "1.5 MB")
  String getFileSizeFormatted(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
  
  /// Get video duration in human-readable format
  /// 
  /// [seconds] - duration in seconds
  /// Returns formatted string (e.g., "1:30")
  String getDurationFormatted(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
