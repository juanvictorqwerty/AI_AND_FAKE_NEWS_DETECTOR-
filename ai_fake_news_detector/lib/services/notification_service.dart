import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ai_fake_news_detector/services/fact_check_service.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';

class NotificationService extends GetxService {
  static const MethodChannel _channel = MethodChannel('fact_check_channel');
  
  final FactCheckService _factCheckService = Get.find<FactCheckService>();
  final AuthController _authController = Get.find<AuthController>();
  
  final RxBool isServiceRunning = false.obs;
  final RxString lastResult = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    _setupMethodChannel();
    _checkServiceState();
  }
  
  /// Check the actual service state from the Kotlin side
  Future<void> _checkServiceState() async {
    try {
      final result = await _channel.invokeMethod('isNotificationServiceRunning');
      isServiceRunning.value = result == true;
      debugPrint('NotificationService: Service state checked on init: ${isServiceRunning.value}');
    } catch (e) {
      debugPrint('NotificationService: Error checking service state: $e');
      // If we can't check, assume it's not running
      isServiceRunning.value = false;
    }
  }
  
  // Static method to set up channel before service initialization
  static void setupChannel() {
    debugPrint('NotificationService: Setting up MethodChannel handler');
    _channel.setMethodCallHandler((MethodCall call) async {
      debugPrint('NotificationService: MethodChannel received: ${call.method}');
      switch (call.method) {
        case 'onNotificationInput':
          final String text = call.arguments as String;
          debugPrint('NotificationService: onNotificationInput called with text: $text');
          final instance = Get.find<NotificationService>();
          await instance._handleNotificationInput(text);
          break;
        default:
          debugPrint('NotificationService: Unknown method ${call.method}');
      }
    });
  }
  
  void _setupMethodChannel() {
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onNotificationInput':
          final String text = call.arguments as String;
          await _handleNotificationInput(text);
          break;
        default:
          debugPrint('NotificationService: Unknown method ${call.method}');
      }
    });
  }
  
  Future<void> _handleNotificationInput(String text) async {
    debugPrint('NotificationService: ========== RECEIVED INPUT ==========');
    debugPrint('NotificationService: Text: $text');
    debugPrint('NotificationService: Auth token available: ${_authController.token.value.isNotEmpty}');
    
    try {
      // Get the auth token
      final token = _authController.token.value;
      if (token.isEmpty) {
        debugPrint('NotificationService: ERROR - No auth token available');
        await _updateNotificationResult('Error: Not authenticated. Please login first.');
        return;
      }
      
      debugPrint('NotificationService: Calling fact check service...');
      // Call the fact check service
      final result = await _factCheckService.searchFactCheck(
        claim: text,
        token: token,
      );
      debugPrint('NotificationService: Fact check result: $result');
      
      if (result['success'] == true) {
        final factCheckResult = result['result'];
        final verdict = factCheckResult.combinedVerdict;
        final reason = factCheckResult.verdict?.reason ?? 'No reason available';
        final evidenceSummary = factCheckResult.evidenceSummary;
        
        // Format the result for notification
        final resultText = 'Verdict: $verdict\n$reason\n\n$evidenceSummary';
        lastResult.value = resultText;
        
        debugPrint('NotificationService: SUCCESS - Updating notification with result');
        debugPrint('NotificationService: Result text: $resultText');
        
        // Update the notification with the result
        await _updateNotificationResult(resultText);
      } else {
        final errorMessage = result['message'] ?? 'Fact check failed';
        debugPrint('NotificationService: FAILED - Updating notification with error: $errorMessage');
        await _updateNotificationResult('Error: $errorMessage');
      }
    } catch (e) {
      debugPrint('NotificationService: Error processing input: $e');
      await _updateNotificationResult('Error: ${e.toString()}');
    }
  }
  
  Future<void> _updateNotificationResult(String result) async {
    try {
      debugPrint('NotificationService: Calling updateNotificationResult with: $result');
      await _channel.invokeMethod('updateNotificationResult', {'result': result});
      debugPrint('NotificationService: updateNotificationResult called successfully');
    } catch (e) {
      debugPrint('NotificationService: Error updating notification: $e');
    }
  }
  
  Future<bool> startNotificationService() async {
    try {
      final result = await _channel.invokeMethod('startNotificationService');
      isServiceRunning.value = result == true;
      debugPrint('NotificationService: Service started: $result');
      return result == true;
    } catch (e) {
      debugPrint('NotificationService: Error starting service: $e');
      return false;
    }
  }
  
  Future<bool> stopNotificationService() async {
    try {
      final result = await _channel.invokeMethod('stopNotificationService');
      isServiceRunning.value = false;
      debugPrint('NotificationService: Service stopped: $result');
      return result == true;
    } catch (e) {
      debugPrint('NotificationService: Error stopping service: $e');
      return false;
    }
  }
  
  Future<void> updateNotificationWithResult(String result) async {
    await _updateNotificationResult(result);
  }
  
  /// Manually refresh the service state from the Kotlin side
  /// This can be called from the UI to ensure the state is up to date
  Future<void> refreshServiceState() async {
    await _checkServiceState();
  }
}
