import 'dart:async';
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
  }
  
  // Static method to set up channel before service initialization
  static void setupChannel() {
    print('NotificationService: Setting up MethodChannel handler');
    _channel.setMethodCallHandler((MethodCall call) async {
      print('NotificationService: MethodChannel received: ${call.method}');
      switch (call.method) {
        case 'onNotificationInput':
          final String text = call.arguments as String;
          print('NotificationService: onNotificationInput called with text: $text');
          final instance = Get.find<NotificationService>();
          await instance._handleNotificationInput(text);
          break;
        default:
          print('NotificationService: Unknown method ${call.method}');
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
          print('NotificationService: Unknown method ${call.method}');
      }
    });
  }
  
  Future<void> _handleNotificationInput(String text) async {
    print('NotificationService: ========== RECEIVED INPUT ==========');
    print('NotificationService: Text: $text');
    print('NotificationService: Auth token available: ${_authController.token.value.isNotEmpty}');
    
    try {
      // Get the auth token
      final token = _authController.token.value;
      if (token.isEmpty) {
        print('NotificationService: ERROR - No auth token available');
        await _updateNotificationResult('Error: Not authenticated. Please login first.');
        return;
      }
      
      print('NotificationService: Calling fact check service...');
      // Call the fact check service
      final result = await _factCheckService.searchFactCheck(
        claim: text,
        token: token,
      );
      print('NotificationService: Fact check result: $result');
      
      if (result['success'] == true) {
        final factCheckResult = result['result'];
        final verdict = factCheckResult.combinedVerdict;
        final reason = factCheckResult.verdict?.reason ?? 'No reason available';
        final evidenceSummary = factCheckResult.evidenceSummary;
        
        // Format the result for notification
        final resultText = 'Verdict: $verdict\n$reason\n\n$evidenceSummary';
        lastResult.value = resultText;
        
        print('NotificationService: SUCCESS - Updating notification with result');
        print('NotificationService: Result text: $resultText');
        
        // Update the notification with the result
        await _updateNotificationResult(resultText);
      } else {
        final errorMessage = result['message'] ?? 'Fact check failed';
        print('NotificationService: FAILED - Updating notification with error: $errorMessage');
        await _updateNotificationResult('Error: $errorMessage');
      }
    } catch (e) {
      print('NotificationService: Error processing input: $e');
      await _updateNotificationResult('Error: ${e.toString()}');
    }
  }
  
  Future<void> _updateNotificationResult(String result) async {
    try {
      print('NotificationService: Calling updateNotificationResult with: $result');
      await _channel.invokeMethod('updateNotificationResult', {'result': result});
      print('NotificationService: updateNotificationResult called successfully');
    } catch (e) {
      print('NotificationService: Error updating notification: $e');
    }
  }
  
  Future<bool> startNotificationService() async {
    try {
      final result = await _channel.invokeMethod('startNotificationService');
      isServiceRunning.value = result == true;
      print('NotificationService: Service started: $result');
      return result == true;
    } catch (e) {
      print('NotificationService: Error starting service: $e');
      return false;
    }
  }
  
  Future<bool> stopNotificationService() async {
    try {
      final result = await _channel.invokeMethod('stopNotificationService');
      isServiceRunning.value = false;
      print('NotificationService: Service stopped: $result');
      return result == true;
    } catch (e) {
      print('NotificationService: Error stopping service: $e');
      return false;
    }
  }
  
  Future<void> updateNotificationWithResult(String result) async {
    await _updateNotificationResult(result);
  }
}
