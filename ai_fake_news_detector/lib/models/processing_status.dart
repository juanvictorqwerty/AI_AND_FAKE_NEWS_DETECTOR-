/// Model for processing status response from backend
/// 
/// Tracks the status of file processing (pending, processing, completed, failed)
class ProcessingStatus {
  final String status; // "pending", "processing", "completed", "failed"
  final String fileId;
  final String? message;
  final int? progress; // 0-100

  ProcessingStatus({
    required this.status,
    required this.fileId,
    this.message,
    this.progress,
  });

  /// Create ProcessingStatus from JSON response
  factory ProcessingStatus.fromJson(Map<String, dynamic> json) {
    return ProcessingStatus(
      status: json['status'] ?? 'pending',
      fileId: json['file_id'] ?? '',
      message: json['message'],
      progress: json['progress'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'file_id': fileId,
      'message': message,
      'progress': progress,
    };
  }

  /// Check if processing is complete
  bool get isCompleted => status.toLowerCase() == 'completed';

  /// Check if processing failed
  bool get isFailed => status.toLowerCase() == 'failed';

  /// Check if still processing
  bool get isProcessing => status.toLowerCase() == 'processing' || status.toLowerCase() == 'pending';

  /// Get formatted progress percentage
  String get progressPercentage => '${progress ?? 0}%';

  @override
  String toString() {
    return 'ProcessingStatus(status: $status, fileId: $fileId, message: $message, progress: $progress)';
  }
}
