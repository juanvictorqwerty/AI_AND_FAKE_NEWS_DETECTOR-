/// Model for file upload response from backend
///
/// Contains the file_id returned after successful upload
class UploadResponse {
  final bool success;
  final String fileId;
  final String message;
  final int? fileSize;
  final String? fileType;

  UploadResponse({
    required this.success,
    required this.fileId,
    required this.message,
    this.fileSize,
    this.fileType,
  });

  /// Create UploadResponse from JSON response
  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      success: json['success'] ?? false,
      fileId: json['file_id'] ?? '',
      message: json['message'] ?? '',
      fileSize: json['file_size'],
      fileType: json['file_type'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'file_id': fileId,
      'message': message,
      'file_size': fileSize,
      'file_type': fileType,
    };
  }

  @override
  String toString() {
    return 'UploadResponse(success: $success, fileId: $fileId, message: $message, fileSize: $fileSize, fileType: $fileType)';
  }
}
