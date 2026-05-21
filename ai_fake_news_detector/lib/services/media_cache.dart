import 'dart:io';
import 'package:flutter/foundation.dart';

class MediaCache {
  // Private constructor
  MediaCache._();

  static File? cachedFile;
  static Uint8List? cachedBytes;
  
  /// Type of media: 'image', 'video', 'text'
  static String? type;

  /// Clear the cache, e.g. after results are dismissed or user selects a new file
  static void clear() {
    cachedFile = null;
    cachedBytes = null;
    type = null;
  }
}
