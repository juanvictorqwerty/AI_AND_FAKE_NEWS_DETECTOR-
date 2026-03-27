/// Model for AI analysis result from backend
///
/// Contains the analysis label (AI/Human), confidence score, and probabilities
class AnalysisResult {
  final String fileId;
  final String status; // "processing", "completed", "failed"
  final String label; // "AI" or "Human"
  final double confidence; // 0.0 to 1.0
  final Map<String, double> probabilities; // {"ai": 0.85, "human": 0.15}
  final String? error;
  final double? processingTime;

  AnalysisResult({
    required this.fileId,
    required this.status,
    required this.label,
    required this.confidence,
    required this.probabilities,
    this.error,
    this.processingTime,
  });

  /// Create AnalysisResult from JSON response
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    // Parse probabilities map
    Map<String, double> parsedProbabilities = {};
    if (json['probabilities'] != null) {
      final probs = json['probabilities'] as Map<String, dynamic>;
      probs.forEach((key, value) {
        parsedProbabilities[key] = (value as num).toDouble();
      });
    }

    return AnalysisResult(
      fileId: json['file_id'] ?? '',
      status: json['status'] ?? 'processing',
      label: json['label'] ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      probabilities: parsedProbabilities,
      error: json['error'],
      processingTime: (json['processing_time'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'file_id': fileId,
      'status': status,
      'label': label,
      'confidence': confidence,
      'probabilities': probabilities,
      'error': error,
      'processing_time': processingTime,
    };
  }

  /// Check if result indicates AI-generated content
  bool get isAi => label.toLowerCase() == 'ai';

  /// Check if result indicates human-generated content
  bool get isHuman => label.toLowerCase() == 'human';

  /// Check if there was an error
  bool get hasError => error != null && error!.isNotEmpty;

  /// Check if processing is complete
  bool get isCompleted => status.toLowerCase() == 'completed';

  /// Check if processing failed
  bool get isFailed => status.toLowerCase() == 'failed';

  /// Check if still processing
  bool get isProcessing => status.toLowerCase() == 'processing';

  /// Get confidence as percentage string
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get AI probability as percentage string
  String get aiProbabilityPercentage {
    final aiProb = probabilities['ai'] ?? 0.0;
    return '${(aiProb * 100).toStringAsFixed(1)}%';
  }

  /// Get Human probability as percentage string
  String get humanProbabilityPercentage {
    final humanProb = probabilities['human'] ?? 0.0;
    return '${(humanProb * 100).toStringAsFixed(1)}%';
  }

  /// Get AI probability value (0.0 to 1.0)
  double get aiProbability => probabilities['ai'] ?? 0.0;

  /// Get Human probability value (0.0 to 1.0)
  double get humanProbability => probabilities['human'] ?? 0.0;

  @override
  String toString() {
    return 'AnalysisResult(fileId: $fileId, status: $status, label: $label, confidence: $confidence, probabilities: $probabilities, error: $error, processingTime: $processingTime)';
  }
}
