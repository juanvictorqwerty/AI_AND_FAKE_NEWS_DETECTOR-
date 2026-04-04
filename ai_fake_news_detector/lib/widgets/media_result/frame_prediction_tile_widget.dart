import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/models/video_frame_result.dart';

/// A widget for displaying a single frame prediction tile.
class FramePredictionTileWidget extends StatelessWidget {
  final FramePrediction frame;

  const FramePredictionTileWidget({super.key, required this.frame});

  @override
  Widget build(BuildContext context) {
    final bool isAi = frame.isAi;
    final Color color = isAi ? Colors.red[400]! : Colors.green[400]!;
    final IconData icon = isAi ? Icons.smart_toy : Icons.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  frame.filename,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${frame.prediction.toUpperCase()} - ${frame.confidencePercentage}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
