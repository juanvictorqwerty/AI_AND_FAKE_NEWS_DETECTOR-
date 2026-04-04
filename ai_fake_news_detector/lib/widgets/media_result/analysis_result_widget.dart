import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/models/analysis_result.dart';
import 'package:ai_fake_news_detector/widgets/media_result/probability_bar_widget.dart';

/// A widget for displaying analysis results for single media files.
class AnalysisResultWidget extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final AnalysisResult? result;

  const AnalysisResultWidget({
    super.key,
    required this.isLoading,
    required this.error,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(error!, style: TextStyle(color: Colors.red[700])),
            ),
          ],
        ),
      );
    }

    if (result == null) return const SizedBox.shrink();

    // Determine colors based on confidence level
    final bool isLowConfidence = result!.confidence < 0.7;
    final Color backgroundColor;
    final Color borderColor;
    final Color iconColor;
    final Color textColor;
    final IconData icon;

    if (isLowConfidence) {
      // Low confidence (< 70%) - use yellow
      backgroundColor = Colors.yellow[50]!;
      borderColor = Colors.yellow[300]!;
      iconColor = Colors.yellow[700]!;
      textColor = Colors.yellow[700]!;
      icon = Icons.warning_amber_rounded;
    } else if (result!.isAi) {
      // High confidence AI - use red
      backgroundColor = Colors.red[50]!;
      borderColor = Colors.red[300]!;
      iconColor = Colors.red[700]!;
      textColor = Colors.red[700]!;
      icon = Icons.smart_toy;
    } else {
      // High confidence Human - use green
      backgroundColor = Colors.green[50]!;
      borderColor = Colors.green[300]!;
      iconColor = Colors.green[700]!;
      textColor = Colors.green[700]!;
      icon = Icons.person;
    }

    return Container(
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
                      result!.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Confidence: ${result!.confidencePercentage}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
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
            value: result!.aiProbability,
            color: Colors.red[400]!,
          ),
          const SizedBox(height: 8),
          ProbabilityBarWidget(
            label: 'Human',
            value: result!.humanProbability,
            color: Colors.green[400]!,
          ),
          if (result!.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result!.error!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
