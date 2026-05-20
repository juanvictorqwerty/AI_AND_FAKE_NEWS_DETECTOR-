import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/services/thumbnail_service.dart';

/// VideoThumbnailPreviewWidget - Displays video thumbnail with loading state
///
/// Features:
/// - Async thumbnail generation
/// - Loading and error states
/// - Memory efficient
/// - Works with local and network videos
class VideoThumbnailPreviewWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;
  final int quality;
  final int timeMs;
  final BoxFit fit;

  const VideoThumbnailPreviewWidget({
    super.key,
    required this.videoPath,
    this.width = 200,
    this.height = 120,
    this.quality = 50,
    this.timeMs = 0,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailPreviewWidget> createState() =>
      _VideoThumbnailPreviewWidgetState();
}

class _VideoThumbnailPreviewWidgetState
    extends State<VideoThumbnailPreviewWidget> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    _thumbnailFuture = ThumbnailService().getThumbnail(
      videoPath: widget.videoPath,
      quality: widget.quality,
      timeMs: widget.timeMs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!, width: 1),
            ),
            child: Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.red[400],
                size: 32,
              ),
            ),
          );
        }

        if (snapshot.data == null) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: const Center(
              child: Icon(Icons.video_library_outlined, color: Colors.grey),
            ),
          );
        }

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              snapshot.data!,
              fit: widget.fit,
              filterQuality: FilterQuality.low,
            ),
          ),
        );
      },
    );
  }
}

/// ImageThumbnailPreviewWidget - Displays image thumbnail (lightweight version of Image.file)
///
/// Features:
/// - Async loading
/// - Memory efficient
/// - Loading and error states
class ImageThumbnailPreviewWidget extends StatefulWidget {
  final String imagePath;
  final double width;
  final double height;
  final BoxFit fit;

  const ImageThumbnailPreviewWidget({
    super.key,
    required this.imagePath,
    this.width = 200,
    this.height = 200,
    this.fit = BoxFit.cover,
  });

  @override
  State<ImageThumbnailPreviewWidget> createState() =>
      _ImageThumbnailPreviewWidgetState();
}

class _ImageThumbnailPreviewWidgetState
    extends State<ImageThumbnailPreviewWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image(
          image: FileImage(File(widget.imagePath)),
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.red[50],
              child: Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red[400],
                  size: 32,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// CompactMediaThumbnailWidget - Compact thumbnail display (e.g., in lists)
///
/// Shows media preview with media type indicator
class CompactMediaThumbnailWidget extends StatelessWidget {
  final String mediaPath;
  final String mediaType; // 'image' or 'video'
  final VoidCallback? onTap;

  const CompactMediaThumbnailWidget({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Media thumbnail
          if (mediaType == 'video')
            VideoThumbnailPreviewWidget(
              videoPath: mediaPath,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            )
          else
            ImageThumbnailPreviewWidget(
              imagePath: mediaPath,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),

          // Media type badge
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mediaType == 'video' ? Icons.play_arrow : Icons.image,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    mediaType == 'video' ? 'Video' : 'Image',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
