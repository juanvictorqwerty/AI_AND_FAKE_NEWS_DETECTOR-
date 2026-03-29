/// Model for video frame analysis result from /upload/video endpoint
///
/// Contains aggregated analysis result and per-frame predictions
class VideoFrameResult {
  final String status;
  final String prediction;
  final double confidence;
  final int frameCount;
  final int validFrameCount;
  final double aggregatedScore;
  final List<FramePrediction> frames;
  final Map<String, LabelStats> labelDistribution;
  final double totalProcessingTime;
  final String? error;

  VideoFrameResult({
    required this.status,
    required this.prediction,
    required this.confidence,
    required this.frameCount,
    required this.validFrameCount,
    required this.aggregatedScore,
    required this.frames,
    required this.labelDistribution,
    required this.totalProcessingTime,
    this.error,
  });

  /// Create VideoFrameResult from JSON response
  factory VideoFrameResult.fromJson(Map<String, dynamic> json) {
    // Parse frames list
    List<FramePrediction> framesList = [];
    if (json['frames'] != null) {
      final framesJson = json['frames'] as List;
      framesList = framesJson
          .map((frameJson) => FramePrediction.fromJson(frameJson as Map<String, dynamic>))
          .toList();
    }

    // Parse label distribution
    Map<String, LabelStats> labelDistMap = {};
    if (json['label_distribution'] != null) {
      final distJson = json['label_distribution'] as Map<String, dynamic>;
      distJson.forEach((key, value) {
        labelDistMap[key] = LabelStats.fromJson(value as Map<String, dynamic>);
      });
    }

    return VideoFrameResult(
      status: json['status'] as String? ?? '',
      prediction: json['prediction'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      frameCount: json['frame_count'] as int? ?? 0,
      validFrameCount: json['valid_frame_count'] as int? ?? 0,
      aggregatedScore: (json['aggregated_score'] as num?)?.toDouble() ?? 0.0,
      frames: framesList,
      labelDistribution: labelDistMap,
      totalProcessingTime: (json['total_processing_time'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'prediction': prediction,
      'confidence': confidence,
      'frame_count': frameCount,
      'valid_frame_count': validFrameCount,
      'aggregated_score': aggregatedScore,
      'frames': frames.map((frame) => frame.toJson()).toList(),
      'label_distribution': labelDistribution.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'total_processing_time': totalProcessingTime,
      'error': error,
    };
  }

  /// Check if result indicates AI-generated content
  bool get isAi => prediction.toLowerCase() == 'ai' || prediction.toLowerCase() == 'artificial';

  /// Check if result indicates human-generated content
  bool get isHuman => prediction.toLowerCase() == 'human';

  /// Check if there was an error
  bool get hasError => error != null && error!.isNotEmpty;

  /// Check if processing is complete
  bool get isCompleted => status.toLowerCase() == 'completed';

  /// Check if processing failed
  bool get isFailed => status.toLowerCase() == 'failed';

  /// Get confidence as percentage string
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get aggregated score as percentage string
  String get aggregatedScorePercentage => '${(aggregatedScore * 100).toStringAsFixed(1)}%';

  @override
  String toString() {
    return 'VideoFrameResult(status: $status, prediction: $prediction, confidence: $confidence, '
        'frameCount: $frameCount, validFrameCount: $validFrameCount, aggregatedScore: $aggregatedScore, '
        'frames: ${frames.length} frames, totalProcessingTime: $totalProcessingTime, error: $error)';
  }
}

/// Model for individual frame prediction
class FramePrediction {
  final String filename;
  final String prediction;
  final double confidence;
  final String? url;

  FramePrediction({
    required this.filename,
    required this.prediction,
    required this.confidence,
    this.url,
  });

  /// Create FramePrediction from JSON
  factory FramePrediction.fromJson(Map<String, dynamic> json) {
    return FramePrediction(
      filename: json['filename'] as String? ?? '',
      prediction: json['prediction'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      url: json['url'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'prediction': prediction,
      'confidence': confidence,
      'url': url,
    };
  }

  /// Check if prediction indicates AI-generated content
  bool get isAi => prediction.toLowerCase() == 'ai' || prediction.toLowerCase() == 'artificial';

  /// Check if prediction indicates human-generated content
  bool get isHuman => prediction.toLowerCase() == 'human';

  /// Get confidence as percentage string
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  @override
  String toString() {
    return 'FramePrediction(filename: $filename, prediction: $prediction, confidence: $confidence, url: $url)';
  }
}

/// Model for label statistics
class LabelStats {
  final int count;
  final double totalConfidence;
  final double avgConfidence;

  LabelStats({
    required this.count,
    required this.totalConfidence,
    required this.avgConfidence,
  });

  /// Create LabelStats from JSON
  factory LabelStats.fromJson(Map<String, dynamic> json) {
    return LabelStats(
      count: json['count'] as int? ?? 0,
      totalConfidence: (json['total_confidence'] as num?)?.toDouble() ?? 0.0,
      avgConfidence: (json['avg_confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'total_confidence': totalConfidence,
      'avg_confidence': avgConfidence,
    };
  }

  /// Get average confidence as percentage string
  String get avgConfidencePercentage => '${(avgConfidence * 100).toStringAsFixed(1)}%';

  @override
  String toString() {
    return 'LabelStats(count: $count, totalConfidence: $totalConfidence, avgConfidence: $avgConfidence)';
  }
}
