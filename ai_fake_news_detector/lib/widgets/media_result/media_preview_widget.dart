import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/media_result/placeholder_widget.dart';

/// A widget for displaying media preview (image or video).
class MediaPreviewWidget extends StatefulWidget {
  final String? filePath;
  final String? fileType;
  final VideoPlayerController? videoController;
  final bool isVideoPlaying;
  final VoidCallback? onTogglePlayback;

  const MediaPreviewWidget({
    super.key,
    required this.filePath,
    required this.fileType,
    this.videoController,
    this.isVideoPlaying = false,
    this.onTogglePlayback,
  });

  @override
  State<MediaPreviewWidget> createState() => _MediaPreviewWidgetState();
}

class _MediaPreviewWidgetState extends State<MediaPreviewWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.filePath == null) {
      return PlaceholderWidget(
        icon: Icons.error_outline,
        text: 'No file provided',
      );
    }

    if (widget.fileType == 'image') {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(widget.filePath!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => PlaceholderWidget(
              icon: Icons.error_outline,
              text: 'Error loading image',
              color: Colors.red[400],
              height: 300,
            ),
          ),
        ),
      );
    }

    if (widget.fileType == 'video') {
      if (widget.videoController != null &&
          widget.videoController!.value.isInitialized) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: widget.videoController!.value.aspectRatio,
                  child: VideoPlayer(widget.videoController!),
                ),
                IconButton(
                  icon: Icon(
                    widget.isVideoPlaying ? Icons.pause : Icons.play_arrow,
                    size: 64,
                    color: Colors.white,
                  ),
                  onPressed: widget.onTogglePlayback,
                ),
              ],
            ),
          ),
        );
      }
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Center(
          child: CircularProgressIndicator(color: GlobalColors.mainColor),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
