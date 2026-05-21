import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

/// ThumbnailService - Efficient async video thumbnail generation with caching
///
/// Features:
/// - Async thumbnail generation using get_thumbnail_video
/// - Local filesystem caching to avoid regeneration
/// - Network URL support with automatic downloading
/// - Memory-efficient with configurable quality
/// - Error handling for invalid/corrupted videos
class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();

  factory ThumbnailService() {
    return _instance;
  }

  ThumbnailService._internal();

  // In-memory cache for quick access
  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, String> _filePathCache = {}; // Hash -> file path

  // Thumbnail directory
  Directory? _thumbnailDir;

  // Dio instance for downloading remote images
  late final Dio _dio = Dio();

  /// Initialize thumbnail directory
  Future<void> init() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _thumbnailDir = Directory('${appDir.path}/thumbnails');

      // Create directory if it doesn't exist
      if (!await _thumbnailDir!.exists()) {
        await _thumbnailDir!.create(recursive: true);
        debugPrint('[ThumbnailService] Created thumbnail cache directory');
      }
    } catch (e) {
      debugPrint('[ThumbnailService] Error initializing cache directory: $e');
    }
  }

  /// Generate or retrieve cached thumbnail for a video
  ///
  /// Returns:
  /// - Uint8List: Raw thumbnail image data
  /// - null: If thumbnail generation fails
  ///
  /// Parameters:
  /// - videoPath: Local file path or network URL
  /// - quality: Thumbnail image quality (0-100, default 50)
  /// - timeMs: Position in video to capture (ms, default 0 for first frame)
  Future<Uint8List?> getThumbnail({
    required String videoPath,
    int quality = 50,
    int timeMs = 0,
  }) async {
    try {
      // Generate cache key from video path and parameters
      final cacheKey = _generateCacheKey(videoPath, quality, timeMs);

      // Check memory cache first (fastest)
      if (_memoryCache.containsKey(cacheKey)) {
        debugPrint('[ThumbnailService] Cache HIT (memory): $videoPath');
        return _memoryCache[cacheKey];
      }

      // Check file cache second (faster than regeneration)
      final cachedFilePath = _filePathCache[cacheKey];
      if (cachedFilePath != null && await File(cachedFilePath).exists()) {
        debugPrint('[ThumbnailService] Cache HIT (file): $videoPath');
        try {
          final bytes = await File(cachedFilePath).readAsBytes();
          _memoryCache[cacheKey] = bytes; // Restore to memory cache
          return bytes;
        } catch (e) {
          debugPrint('[ThumbnailService] Error reading cached file: $e');
          // Fall through to regeneration
        }
      }

      debugPrint('[ThumbnailService] Cache MISS: $videoPath - Generating...');

      // Determine if video is network URL
      final isNetworkUrl =
          videoPath.startsWith('http://') || videoPath.startsWith('https://');

      String localVideoPath = videoPath;

      // Download network video if needed
      if (isNetworkUrl) {
        localVideoPath = await _downloadVideo(videoPath);
        if (localVideoPath.isEmpty) {
          debugPrint(
            '[ThumbnailService] Failed to download remote video: $videoPath',
          );
          return null;
        }
      }

      // Generate thumbnail
      final thumbnail = await _generateThumbnailBytes(
        videoPath: localVideoPath,
        quality: quality,
        timeMs: timeMs,
      );

      if (thumbnail == null) {
        debugPrint(
          '[ThumbnailService] Thumbnail generation failed for: $videoPath',
        );
        return null;
      }

      // Cache the result
      _memoryCache[cacheKey] = thumbnail;

      // Also cache to file
      try {
        final filePath = await _saveThumbnailToFile(cacheKey, thumbnail);
        _filePathCache[cacheKey] = filePath;
      } catch (e) {
        debugPrint('[ThumbnailService] Warning: Could not cache to file: $e');
        // Still return the thumbnail even if file caching fails
      }

      debugPrint('[ThumbnailService] Thumbnail generated successfully');
      return thumbnail;
    } catch (e) {
      debugPrint('[ThumbnailService] ERROR: $e');
      return null;
    }
  }

  /// Get thumbnail as file path for direct file system access
  ///
  /// Useful for:
  /// - Passing to native code
  /// - Loading with Image.file()
  /// - Sharing files
  Future<String?> getThumbnailPath({
    required String videoPath,
    int quality = 50,
    int timeMs = 0,
  }) async {
    try {
      final cacheKey = _generateCacheKey(videoPath, quality, timeMs);

      // Check file cache first
      final cachedPath = _filePathCache[cacheKey];
      if (cachedPath != null && await File(cachedPath).exists()) {
        debugPrint('[ThumbnailService] Using cached file: $cachedPath');
        return cachedPath;
      }

      // Generate thumbnail
      final thumbnail = await getThumbnail(
        videoPath: videoPath,
        quality: quality,
        timeMs: timeMs,
      );

      if (thumbnail == null) return null;

      // Return cached file path
      return _filePathCache[cacheKey];
    } catch (e) {
      debugPrint('[ThumbnailService] ERROR getting thumbnail path: $e');
      return null;
    }
  }

  /// Clear all caches
  Future<void> clearCache() async {
    try {
      _memoryCache.clear();
      _filePathCache.clear();

      if (_thumbnailDir != null && await _thumbnailDir!.exists()) {
        await _thumbnailDir!.delete(recursive: true);
        await _thumbnailDir!.create(recursive: true);
      }

      debugPrint('[ThumbnailService] Cache cleared');
    } catch (e) {
      debugPrint('[ThumbnailService] Error clearing cache: $e');
    }
  }

  /// Clear memory cache only (keep file cache)
  void clearMemoryCache() {
    _memoryCache.clear();
    debugPrint('[ThumbnailService] Memory cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheSize': _memoryCache.length,
      'fileCacheSize': _filePathCache.length,
      'cacheDirectory': _thumbnailDir?.path,
    };
  }

  // ============ PRIVATE METHODS ============

  /// Generate cache key from video path and parameters
  String _generateCacheKey(String videoPath, int quality, int timeMs) {
    // Create a unique key combining path and parameters
    return '${videoPath.hashCode}_q${quality}_t$timeMs';
  }

  /// Generate thumbnail bytes using get_thumbnail_video package
  Future<Uint8List?> _generateThumbnailBytes({
    required String videoPath,
    required int quality,
    required int timeMs,
  }) async {
    try {
      // Use get_thumbnail_video for efficient thumbnail generation
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200, // Mobile-friendly height
        maxWidth: 200,
        timeMs: timeMs,
        quality: quality,
      );

      return thumbnail;
    } catch (e) {
      debugPrint('[ThumbnailService] Error generating thumbnail: $e');
      return null;
    }
  }

  /// Save thumbnail to file
  Future<String> _saveThumbnailToFile(String cacheKey, Uint8List data) async {
    if (_thumbnailDir == null) await init();

    final filePath = '${_thumbnailDir!.path}/$cacheKey.jpg';
    final file = File(filePath);
    await file.writeAsBytes(data);

    debugPrint('[ThumbnailService] Saved thumbnail to: $filePath');
    return filePath;
  }

  /// Download video from network URL
  Future<String> _downloadVideo(String url) async {
    try {
      if (_thumbnailDir == null) await init();

      final fileName = url.hashCode.toString();
      final filePath = '${_thumbnailDir!.path}/$fileName.tmp';
      final file = File(filePath);

      // Check if already downloaded
      if (await file.exists()) {
        debugPrint(
          '[ThumbnailService] Using previously downloaded video: $url',
        );
        return filePath;
      }

      debugPrint('[ThumbnailService] Downloading video: $url');

      // Download with timeout and size limit
      final response = await _dio.download(
        url,
        filePath,
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        debugPrint('[ThumbnailService] Video downloaded successfully');
        return filePath;
      }

      throw Exception('Download failed with status: ${response.statusCode}');
    } catch (e) {
      debugPrint('[ThumbnailService] Error downloading video: $e');
      return '';
    }
  }
}

/// Extension to easily access ThumbnailService
extension ThumbnailServiceExt on ThumbnailService {
  /// Quick access to get a thumbnail with default parameters
  Future<Uint8List?> quickThumbnail(String videoPath) {
    return getThumbnail(videoPath: videoPath);
  }
}
