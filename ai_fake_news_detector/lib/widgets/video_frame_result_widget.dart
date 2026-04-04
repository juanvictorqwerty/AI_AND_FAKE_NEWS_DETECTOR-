import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/models/video_frame_result.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/probability_bar_widget.dart';
import 'package:ai_fake_news_detector/widgets/frame_prediction_tile_widget.dart';

/// A widget for displaying video frame analysis results.
class VideoFrameResultWidget extends StatelessWidget {
  final VideoFrameResult? result;

  const VideoFrameResultWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) return const SizedBox.shrink();

    // Determine colors based on confidence level
    final bool isLowConfidence = result.confidence < 0.7;
    final Color backgroundColor;
    final Color borderColor;
    final Color iconColor;
    final Color textColor;
    final IconData icon;

    if (isLowConfidence) {
      backgroundColor = Colors.yellow[50]!;
      borderColor = Colors.yellow[300]!;
      iconColor = Colors.yellow[700]!;
      textColor = Colors.yellow[700]!;
      icon = Icons.warning_amber_rounded;
    } else if (result.isAi) {
      backgroundColor = Colors.red[50]!;
      borderColor = Colors.red[300]!;
      iconColor = Colors.red[700]!;
      textColor = Colors.red[700]!;
      icon = Icons.smart_toy;
    } else {
      backgroundColor = Colors.green[50]!;
      borderColor = Colors.green[300]!;
      iconColor = Colors.green[700]!;
      textColor = Colors.green[700]!;
      icon = Icons.person;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aggregated result card
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.prediction.toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Confidence: ${result.confidencePercentage}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (isLowConfidence)
                          Text(
                            'Low confidence - result may be unreliable',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.yellow[800],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ProbabilityBarWidget(
                label: 'AI',
                value: result.labelDistribution['ai']?.avgConfidence ?? 0.0,
                color: Colors.red[400]!,
              ),
              const SizedBox(height: 8),
              ProbabilityBarWidget(
                label: 'Human',
                value: result.labelDistribution['human']?.avgConfidence ?? 0.0,
                color: Colors.green[400]!,
              ),
              const SizedBox(height: 16),
              // Aggregated score
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aggregated Score',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      result.aggregatedScorePercentage,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GlobalColors.mainColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Frame count info
              Text(
                '${result.validFrameCount}/${result.frameCount} valid frames analyzed',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              if (result.totalProcessingTime > 0)
                Text(
                  'Processing time: ${result.totalProcessingTime.toStringAsFixed(2)}s',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        // Per-frame predictions
        if (result.frames.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Per-Frame Predictions (${result.frames.length} frames)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                ...result.frames.map(
                  (frame) => FramePredictionTileWidget(frame: frame),
                ),
              ],
            ),
          ),
        ],
        // Label distribution
        if (result.labelDistribution.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Label Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                ...result.labelDistribution.entries.map((entry) {
                  final stats = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${stats.count} frames (${stats.avgConfidencePercentage})',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
