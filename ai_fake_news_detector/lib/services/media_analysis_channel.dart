import 'dart:async';
import 'package:flutter/services.dart';

/// Platform channel for communicating with Kotlin media analysis services
///
/// This channel handles:
/// - Starting background analysis
/// - Cancelling background analysis
/// - Receiving analysis results
/// - Receiving analysis errors
/// - Receiving cancellation notifications
class MediaAnalysisChannel {
  static const MethodChannel _channel = MethodChannel('com.example.ai_fake_news_detector/media_analysis');
  
  // Callbacks for analysis events
  static Function(Map<String, dynamic>)? _onAnalysisResult;
  static Function(Map<String, dynamic>)? _onAnalysisError;
  static Function(Map<String, dynamic>)? _onAnalysisCancellation;
  
  /// Initialize the platform channel
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
    print('MediaAnalysisChannel: Initialized');
  }
  
  /// Handle method calls from Kotlin
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('MediaAnalysisChannel: Received method call: ${call.method}');
    
    switch (call.method) {
      case 'onAnalysisResult':
        final resultData = Map<String, dynamic>.from(call.arguments);
        print('MediaAnalysisChannel: Analysis result received: ${resultData['taskId']}');
        _onAnalysisResult?.call(resultData);
        break;
        
      case 'onAnalysisError':
        final errorData = Map<String, dynamic>.from(call.arguments);
        print('MediaAnalysisChannel: Analysis error received: ${errorData['taskId']}');
        _onAnalysisError?.call(errorData);
        break;
        
      case 'onAnalysisCancellation':
        final cancellationData = Map<String, dynamic>.from(call.arguments);
        print('MediaAnalysisChannel: Analysis cancellation received: ${cancellationData['taskId']}');
        _onAnalysisCancellation?.call(cancellationData);
        break;
        
      default:
        print('MediaAnalysisChannel: Unknown method call: ${call.method}');
    }
  }
  
  /// Set callback for analysis results
  static void setOnAnalysisResult(Function(Map<String, dynamic>) callback) {
    _onAnalysisResult = callback;
    print('MediaAnalysisChannel: OnAnalysisResult callback set');
  }
  
  /// Set callback for analysis errors
  static void setOnAnalysisError(Function(Map<String, dynamic>) callback) {
    _onAnalysisError = callback;
    print('MediaAnalysisChannel: OnAnalysisError callback set');
  }
  
  /// Set callback for analysis cancellations
  static void setOnAnalysisCancellation(Function(Map<String, dynamic>) callback) {
    _onAnalysisCancellation = callback;
    print('MediaAnalysisChannel: OnAnalysisCancellation callback set');
  }
  
  /// Start background analysis using foreground service
  ///
  /// [filePath] - Path to the file to analyze
  /// [fileType] - Type of file ('image' or 'video')
  /// [taskId] - Unique task identifier
  ///
  /// Returns a Map with status and taskId
  static Future<Map<String, dynamic>> startAnalysis(String filePath, String fileType, String taskId) async {
    try {
      print('MediaAnalysisChannel: Starting analysis for task: $taskId');
      
      final result = await _channel.invokeMethod('startAnalysis', {
        'filePath': filePath,
        'fileType': fileType,
        'taskId': taskId,
      });
      
      final resultData = Map<String, dynamic>.from(result);
      print('MediaAnalysisChannel: Analysis started: ${resultData['status']}');
      return resultData;
    } on PlatformException catch (e) {
      print('MediaAnalysisChannel: Error starting analysis: ${e.message}');
      throw Exception('Failed to start analysis: ${e.message}');
    }
  }
  
  /// Cancel background analysis
  ///
  /// [taskId] - Unique task identifier
  ///
  /// Returns a Map with status and taskId
  static Future<Map<String, dynamic>> cancelAnalysis(String taskId) async {
    try {
      print('MediaAnalysisChannel: Cancelling analysis for task: $taskId');
      
      final result = await _channel.invokeMethod('cancelAnalysis', {
        'taskId': taskId,
      });
      
      final resultData = Map<String, dynamic>.from(result);
      print('MediaAnalysisChannel: Analysis cancelled: ${resultData['status']}');
      return resultData;
    } on PlatformException catch (e) {
      print('MediaAnalysisChannel: Error cancelling analysis: ${e.message}');
      throw Exception('Failed to cancel analysis: ${e.message}');
    }
  }
  
  /// Start background work using WorkManager
  ///
  /// [filePath] - Path to the file to analyze
  /// [fileType] - Type of file ('image' or 'video')
  /// [taskId] - Unique task identifier
  ///
  /// Returns a Map with status and taskId
  static Future<Map<String, dynamic>> startBackgroundWork(String filePath, String fileType, String taskId) async {
    try {
      print('MediaAnalysisChannel: Starting background work for task: $taskId');
      
      final result = await _channel.invokeMethod('startBackgroundWork', {
        'filePath': filePath,
        'fileType': fileType,
        'taskId': taskId,
      });
      
      final resultData = Map<String, dynamic>.from(result);
      print('MediaAnalysisChannel: Background work started: ${resultData['status']}');
      return resultData;
    } on PlatformException catch (e) {
      print('MediaAnalysisChannel: Error starting background work: ${e.message}');
      throw Exception('Failed to start background work: ${e.message}');
    }
  }
  
  /// Cancel background work
  ///
  /// [taskId] - Unique task identifier
  ///
  /// Returns a Map with status and taskId
  static Future<Map<String, dynamic>> cancelBackgroundWork(String taskId) async {
    try {
      print('MediaAnalysisChannel: Cancelling background work for task: $taskId');
      
      final result = await _channel.invokeMethod('cancelBackgroundWork', {
        'taskId': taskId,
      });
      
      final resultData = Map<String, dynamic>.from(result);
      print('MediaAnalysisChannel: Background work cancelled: ${resultData['status']}');
      return resultData;
    } on PlatformException catch (e) {
      print('MediaAnalysisChannel: Error cancelling background work: ${e.message}');
      throw Exception('Failed to cancel background work: ${e.message}');
    }
  }
  
  /// Remove all callbacks
  static void dispose() {
    _onAnalysisResult = null;
    _onAnalysisError = null;
    _onAnalysisCancellation = null;
    print('MediaAnalysisChannel: Disposed');
  }
}
