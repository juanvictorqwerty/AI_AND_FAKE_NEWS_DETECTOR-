import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';

/// A widget for displaying action buttons based on the current state.
class ActionButtonsWidget extends StatelessWidget {
  final String? filePath;
  final String? fileType;
  final int? fileSize;
  final bool hasResult;
  final bool hasError;

  const ActionButtonsWidget({
    super.key,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.hasResult,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    if (filePath == null) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 24),
        if (hasError)
          BigButton(
            text: 'Retry Upload',
            onTap: () async {
              // Fix 6 – startAnalysis returns the taskId.
              final taskId = await MediaAnalysisChannel.startAnalysis(
                filePath!,
                fileType!,
              );
              Navigator.pushNamed(
                context,
                '/processing',
                arguments: {
                  'filePath': filePath,
                  'fileType': fileType,
                  'fileSize': fileSize,
                  'taskId': taskId,
                },
              );
            },
            color: Colors.orange,
          ),
        if (hasResult || !hasError)
          BigButton(
            text: 'Upload New File',
            onTap: () => Navigator.pop(context),
            color: Colors.green,
          ),
        const SizedBox(height: 12),
        BigButton(
          text: 'Back to Home',
          onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
          color: Colors.grey[600]!,
        ),
      ],
    );
  }
}
