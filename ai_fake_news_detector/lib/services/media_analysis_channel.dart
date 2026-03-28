import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Singleton channel between Flutter and the Kotlin MediaAnalysisService.
///
/// FIX 1 – Listener lists instead of single-slot callbacks.
///   Previously every call to setOnAnalysisResult() / setOnAnalysisError()
///   silently replaced the previous subscriber, so whichever screen registered
///   last was the only one that ever received the event.  Now every subscriber
///   gets called and can remove itself independently.
///
/// FIX 2 – Progress / status stream.
///   A broadcast StreamController carries upload-progress and intermediate
///   status updates so ProcessingScreen can drive its UI without polling.
///
/// FIX 3 – taskId threading.
///   startAnalysis() returns the taskId it generated so callers can pass it
///   through route arguments and use it for cancellation.
///
/// FIX 4 – Video frame progress and cancellation handlers.
///   Added missing handlers for onVideoFrameProgress and onVideoFrameCancellation
///   events sent from Android's VideoFrameProcessingService.
class MediaAnalysisChannel {
  MediaAnalysisChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.example.ai_fake_news_detector/media_analysis');

  // --------------------------------------------------------------------------
  // Internal listener lists (Fix 1)
  // --------------------------------------------------------------------------
  static final List<void Function(Map<String, dynamic>)> _resultListeners = [];
  static final List<void Function(Map<String, dynamic>)> _errorListeners = [];
  static final List<void Function(Map<String, dynamic>)> _cancellationListeners = [];
  static final List<void Function(Map<String, dynamic>)> _videoFrameResultListeners = [];
  static final List<void Function(Map<String, dynamic>)> _videoFrameErrorListeners = [];
  // FIX 4: Added missing listener lists for video frame progress and cancellation
  static final List<void Function(Map<String, dynamic>)> _videoFrameProgressListeners = [];
  static final List<void Function(Map<String, dynamic>)> _videoFrameCancellationListeners = [];

  // --------------------------------------------------------------------------
  // Progress stream (Fix 2)
  // --------------------------------------------------------------------------
  static final StreamController<AnalysisProgressEvent> _progressController =
      StreamController<AnalysisProgressEvent>.broadcast();

  /// Subscribe to upload / processing progress updates.
  static Stream<AnalysisProgressEvent> get progressStream =>
      _progressController.stream;

  // --------------------------------------------------------------------------
  // Bootstrap – call once from main() or MainActivity equivalent
  // --------------------------------------------------------------------------
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    debugPrint('MediaAnalysisChannel: Received method call: ${call.method}');
    
    switch (call.method) {
      case 'onAnalysisResult':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('MediaAnalysisChannel: Analysis result received: $data');
        for (final cb in List.of(_resultListeners)) {
          cb(data);
        }
        break;

      case 'onAnalysisError':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('MediaAnalysisChannel: Analysis error received: $data');
        for (final cb in List.of(_errorListeners)) {
          cb(data);
        }
        break;

      case 'onAnalysisCancelled':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('MediaAnalysisChannel: Analysis cancelled received: $data');
        for (final cb in List.of(_cancellationListeners)) {
          cb(data);
        }
        break;

      // Fix 2: Kotlin service sends progress events here
      case 'onAnalysisProgress':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('MediaAnalysisChannel: Analysis progress received: $data');
        _progressController.add(AnalysisProgressEvent(
          taskId: data['taskId'] as String,
          status: data['status'] as String,
          progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
        ));
        break;

      // Video frame processing events
      case 'onVideoFrameResult':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('MediaAnalysisChannel: Video frame result received: $data');
        for (final cb in List.of(_videoFrameResultListeners)) {
          cb(data);
        }
        break;

      case 'onVideoFrameError':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('MediaAnalysisChannel: Video frame error received: $data');
        for (final cb in List.of(_videoFrameErrorListeners)) {
          cb(data);
        }
        break;

      // FIX 4: Added missing handlers for video frame progress and cancellation
      case 'onVideoFrameProgress':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('MediaAnalysisChannel: Video frame progress received: $data');
        for (final cb in List.of(_videoFrameProgressListeners)) {
          cb(data);
        }
        break;

      case 'onVideoFrameCancellation':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('MediaAnalysisChannel: Video frame cancellation received: $data');
        for (final cb in List.of(_videoFrameCancellationListeners)) {
          cb(data);
        }
        break;
    }
  }

  // --------------------------------------------------------------------------
  // Subscription management (Fix 1)
  // --------------------------------------------------------------------------

  static void addOnAnalysisResult(void Function(Map<String, dynamic>) cb) =>
      _resultListeners.add(cb);

  static void removeOnAnalysisResult(void Function(Map<String, dynamic>) cb) =>
      _resultListeners.remove(cb);

  static void addOnAnalysisError(void Function(Map<String, dynamic>) cb) =>
      _errorListeners.add(cb);

  static void removeOnAnalysisError(void Function(Map<String, dynamic>) cb) =>
      _errorListeners.remove(cb);

  static void addOnAnalysisCancelled(void Function(Map<String, dynamic>) cb) =>
      _cancellationListeners.add(cb);

  static void removeOnAnalysisCancelled(
          void Function(Map<String, dynamic>) cb) =>
      _cancellationListeners.remove(cb);

  static void addOnVideoFrameResult(void Function(Map<String, dynamic>) cb) =>
      _videoFrameResultListeners.add(cb);

  static void removeOnVideoFrameResult(void Function(Map<String, dynamic>) cb) =>
      _videoFrameResultListeners.remove(cb);

  static void addOnVideoFrameError(void Function(Map<String, dynamic>) cb) =>
      _videoFrameErrorListeners.add(cb);

  static void removeOnVideoFrameError(void Function(Map<String, dynamic>) cb) =>
      _videoFrameErrorListeners.remove(cb);

  // FIX 4: Added subscription management for video frame progress and cancellation
  static void addOnVideoFrameProgress(void Function(Map<String, dynamic>) cb) =>
      _videoFrameProgressListeners.add(cb);

  static void removeOnVideoFrameProgress(void Function(Map<String, dynamic>) cb) =>
      _videoFrameProgressListeners.remove(cb);

  static void addOnVideoFrameCancellation(void Function(Map<String, dynamic>) cb) =>
      _videoFrameCancellationListeners.add(cb);

  static void removeOnVideoFrameCancellation(void Function(Map<String, dynamic>) cb) =>
      _videoFrameCancellationListeners.remove(cb);

  // --------------------------------------------------------------------------
  // Outbound calls to Kotlin
  // --------------------------------------------------------------------------

  /// Start analysis and return the generated taskId (Fix 3).
  static Future<String> startAnalysis(
      String filePath, String fileType) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    await _channel.invokeMethod('startAnalysis', {
      'filePath': filePath,
      'fileType': fileType,
      'taskId': taskId,
    });
    return taskId;
  }

  static Future<void> cancelAnalysis(String taskId) async {
    await _channel.invokeMethod('cancelAnalysis', {'taskId': taskId});
  }
}

/// Carries an intermediate progress event from the Kotlin service.
class AnalysisProgressEvent {
  final String taskId;

  /// e.g. 'uploading' | 'processing' | 'completed' | 'failed' | 'cancelled'
  final String status;

  /// 0.0 – 1.0
  final double progress;

  const AnalysisProgressEvent({
    required this.taskId,
    required this.status,
    required this.progress,
  });
}