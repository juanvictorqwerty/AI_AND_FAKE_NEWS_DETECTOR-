import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';

/// A widget for displaying file information.
class FileInfoWidget extends StatelessWidget {
  final String? filePath;
  final String? fileType;
  final int? fileSize;
  final int? videoDuration;

  const FileInfoWidget({
    super.key,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.videoDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (filePath == null) return const SizedBox.shrink();

    return Container(
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
          Row(
            children: [
              Icon(
                fileType == 'video' ? Icons.videocam : Icons.image,
                color: GlobalColors.mainColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  filePath!.split('/').last,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (fileSize != null) ...[
            const SizedBox(height: 8),
            Text(
              'Size: ${(fileSize! / 1024 / 1024).toStringAsFixed(2)} MB',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
          if (videoDuration != null) ...[
            const SizedBox(height: 4),
            Text(
              'Duration: ${videoDuration}s',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'File validated successfully',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
