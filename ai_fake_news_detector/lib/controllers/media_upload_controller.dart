import 'dart:async';
import 'package:get/get.dart';
import 'package:ai_fake_news_detector/models/upload_response.dart';
import 'package:ai_fake_news_detector/models/analysis_result.dart';
import 'package:ai_fake_news_detector/services/media_api_service.dart';

/// Enum for upload state
enum UploadState {
  idle,
  uploading,
  processing,
  completed,
  failed,
}

/// Controller for managing media upload and processing state
///
/// This controller handles:
/// - Upload state management
/// - Progress tracking
/// - Processing status updates
/// - Error handling
/// - Retry logic
class MediaUploadController extends GetxController {
  final MediaApiService _apiService = Get.find<MediaApiService>();
  
  // Observable state variables
  final uploadState = UploadState.idle.obs;
  final uploadProgress = 0.0.obs;
  final processingStatus = ''.obs;
  final fileId = ''.obs;
  final analysisResult = Rxn<AnalysisResult>();
  final errorMessage = ''.obs;
  
  // File information
  final filePath = ''.obs;
  final fileType = ''.obs;

  /// Check if currently uploading
  bool get isUploading => uploadState.value == UploadState.uploading;

  /// Check if currently processing
  bool get isProcessing => uploadState.value == UploadState.processing;

  /// Check if completed
  bool get isCompleted => uploadState.value == UploadState.completed;

  /// Check if failed
  bool get isFailed => uploadState.value == UploadState.failed;

  /// Check if idle
  bool get isIdle => uploadState.value == UploadState.idle;

  /// Check if busy (uploading or processing)
  bool get isBusy => isUploading || isProcessing;

  /// Get status message for display
  String get statusMessage {
    switch (uploadState.value) {
      case UploadState.idle:
        return 'Ready to upload';
      case UploadState.uploading:
        return 'Uploading... ${(uploadProgress.value * 100).toStringAsFixed(0)}%';
      case UploadState.processing:
        return processingStatus.value.isNotEmpty ? processingStatus.value : 'Processing...';
      case UploadState.completed:
        return 'Analysis complete';
      case UploadState.failed:
        return errorMessage.value;
    }
  }

  /// Upload and process file
  ///
  /// [filePath] - Path to the file to upload
  /// [fileType] - Type of file ('image' or 'video')
  Future<void> uploadAndProcess(String filePath, String fileType) async {
    try {
      // Reset state
      _resetState();
      
      // Set file information
      this.filePath.value = filePath;
      this.fileType.value = fileType;
      
      // Set uploading state
      uploadState.value = UploadState.uploading;
      processingStatus.value = 'Uploading file...';
      
      print('MediaUploadController: Starting upload for $fileType');
      
      // Upload file
      final uploadResponse = await _apiService.uploadFile(filePath, fileType);
      
      if (!uploadResponse.success) {
        throw Exception(uploadResponse.message);
      }
      
      // Store file ID
      fileId.value = uploadResponse.fileId;
      uploadProgress.value = 1.0;
      
      print('MediaUploadController: Upload complete, file_id: ${uploadResponse.fileId}');
      
      // Set processing state
      uploadState.value = UploadState.processing;
      processingStatus.value = 'Processing...';
      
      // Poll until complete
      final result = await _apiService.pollUntilComplete(
        uploadResponse.fileId,
        onStatusUpdate: (result) {
          processingStatus.value = result.isProcessing ? 'Processing...' : result.status;
          print('MediaUploadController: Status update: ${result.status} - ${result.label}');
        },
      );
      
      // Store result
      analysisResult.value = result;
      uploadState.value = UploadState.completed;
      processingStatus.value = 'Analysis complete';
      
      print('MediaUploadController: Processing complete');
      print('MediaUploadController: Result: ${result.label} - ${result.confidencePercentage}');
      
    } catch (e) {
      print('MediaUploadController: Error: $e');
      uploadState.value = UploadState.failed;
      errorMessage.value = _getErrorMessage(e);
      processingStatus.value = 'Failed';
    }
  }

  /// Retry failed upload
  Future<void> retry() async {
    if (filePath.value.isEmpty || fileType.value.isEmpty) {
      print('MediaUploadController: Cannot retry - no file information');
      return;
    }
    
    print('MediaUploadController: Retrying upload');
    await uploadAndProcess(filePath.value, fileType.value);
  }

  /// Reset state to idle
  void resetState() {
    _resetState();
    uploadState.value = UploadState.idle;
  }

  /// Internal reset state
  void _resetState() {
    uploadProgress.value = 0.0;
    processingStatus.value = '';
    fileId.value = '';
    analysisResult.value = null;
    errorMessage.value = '';
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final errorString = error.toString();
    
    if (errorString.contains('TimeoutException') || errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorString.contains('SocketException') || errorString.contains('Network')) {
      return 'Network error. Please check your connection.';
    } else if (errorString.contains('Upload failed')) {
      return errorString;
    } else if (errorString.contains('Processing failed')) {
      return errorString;
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  @override
  void onClose() {
    // Clean up resources
    super.onClose();
  }
}
