import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ai_fake_news_detector/widgets/quick_settings_overlay.dart';

/// Service to handle Quick Settings Tile communication
/// This service manages MethodChannel communication between Flutter and Android
class QuickSettingsService extends GetxService {
  static const String _overlayChannel =
      'com.example.ai_fake_news_detector/overlay';
  static const String _quickSettingsChannel =
      'com.example.ai_fake_news_detector/quick_settings';

  final MethodChannel _overlayChannelHandler =
      const MethodChannel(_overlayChannel);
  final MethodChannel _quickSettingsChannelHandler =
      const MethodChannel(_quickSettingsChannel);

  final RxBool isTileActive = false.obs;

  @override
  void onInit() {
    super.onInit();
    _setupMethodCallHandlers();
    _checkTileState();
  }

  /// Setup MethodChannel handlers to receive calls from Android
  void _setupMethodCallHandlers() {
    _overlayChannelHandler.setMethodCallHandler((call) async {
      debugPrint('Overlay channel received call: ${call.method}');
      
      switch (call.method) {
        case 'showOverlay':
          final triggerSource = call.arguments?['triggerSource'] as String?;
          final message = call.arguments?['message'] as String?;
          _showOverlayFromAndroid(
            triggerSource: triggerSource,
            message: message,
          );
          return true;
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Method ${call.method} not implemented',
          );
      }
    });
  }

  /// Show overlay when triggered from Android Quick Settings
  void _showOverlayFromAndroid({
    String? triggerSource,
    String? message,
  }) {
    debugPrint('Showing overlay from Android - Source: $triggerSource');
    
    // Show the overlay popup
    showQuickSettingsOverlay(
      triggerSource: triggerSource ?? 'Quick Settings',
      message: message ?? 'Fact-check triggered from Quick Settings tile!',
    );
  }

  /// Check current tile state from Android
  Future<void> _checkTileState() async {
    try {
      final result =
          await _quickSettingsChannelHandler.invokeMethod('getTileState');
      isTileActive.value = result == true;
      debugPrint('Tile state: ${isTileActive.value}');
    } on PlatformException catch (e) {
      debugPrint('Error checking tile state: ${e.message}');
    }
  }

  /// Update tile state from Flutter
  Future<void> updateTile() async {
    try {
      await _quickSettingsChannelHandler.invokeMethod('updateTile');
      debugPrint('Tile updated');
    } on PlatformException catch (e) {
      debugPrint('Error updating tile: ${e.message}');
    }
  }

  /// Check if overlay permission is granted
  Future<bool> canDrawOverlays() async {
    try {
      final result =
          await _quickSettingsChannelHandler.invokeMethod('canDrawOverlays');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Error checking overlay permission: ${e.message}');
      return false;
    }
  }

  /// Open overlay settings
  Future<void> openOverlaySettings() async {
    try {
      await _quickSettingsChannelHandler.invokeMethod('openOverlaySettings');
    } on PlatformException catch (e) {
      debugPrint('Error opening overlay settings: ${e.message}');
    }
  }

  /// Show overlay manually from Flutter
  void showOverlay({
    String? triggerSource,
    String? message,
  }) {
    showQuickSettingsOverlay(
      triggerSource: triggerSource ?? 'Manual',
      message: message ?? 'Fact-check triggered manually!',
    );
  }
}
