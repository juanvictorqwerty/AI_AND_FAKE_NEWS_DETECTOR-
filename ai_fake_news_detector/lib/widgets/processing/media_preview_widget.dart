import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_fake_news_detector/services/media_cache.dart';

class MediaPreviewWidget extends StatefulWidget {
  final VideoPlayerController? videoController;
  final bool isVideoPlaying;
  final VoidCallback? onTogglePlayback;

  const MediaPreviewWidget({
    super.key,
    this.videoController,
    this.isVideoPlaying = false,
    this.onTogglePlayback,
  });

  @override
  State<MediaPreviewWidget> createState() => _MediaPreviewWidgetState();
}

class _MediaPreviewWidgetState extends State<MediaPreviewWidget> {
  Uint8List? _videoThumb;
  String? _textSnippet;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final type = MediaCache.type;
    final file = MediaCache.cachedFile;

    if (file == null || type == null) return;

    if (type == 'video') {
      setState(() => _loading = true);
      try {
        final thumb = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 400,
          quality: 50,
        );
        if (mounted) {
          setState(() {
            _videoThumb = thumb;
            _loading = false;
          });
        }
      } catch (e) {
        debugPrint("Error generating video thumbnail: $e");
        if (mounted) setState(() => _loading = false);
      }
    } else if (type == 'text') {
      setState(() => _loading = true);
      try {
        final content = await file.readAsString();
        final lines = content.split('\n').take(5).join('\n');
        if (mounted) {
          setState(() {
            _textSnippet = lines;
            _loading = false;
          });
        }
      } catch (e) {
        debugPrint("Error reading text snippet: $e");
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaCache.cachedFile == null || MediaCache.type == null) {
      return const SizedBox.shrink(); // No media cached
    }

    Widget content;

    if (MediaCache.type == 'image') {
      if (MediaCache.cachedBytes != null) {
        content = Image.memory(
          MediaCache.cachedBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
        );
      } else {
        content = Image.file(
          MediaCache.cachedFile!,
          fit: BoxFit.cover,
          width: double.infinity,
        );
      }
    } else if (MediaCache.type == 'video') {
      if (widget.videoController != null && widget.videoController!.value.isInitialized) {
        content = Stack(
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
        );
      } else if (_loading) {
        content = const Center(child: CircularProgressIndicator());
      } else if (_videoThumb != null) {
        content = Stack(
          alignment: Alignment.center,
          children: [
            Image.memory(
              _videoThumb!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
            ),
          ],
        );
      } else {
        content = const Center(child: Icon(Icons.videocam, size: 48, color: Colors.grey));
      }
    } else if (MediaCache.type == 'text') {
      if (_loading) {
        content = const Center(child: CircularProgressIndicator());
      } else {
        content = Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _textSnippet ?? 'Unable to read text file.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF1A1730),
              height: 1.5,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
    } else {
      content = const Center(child: Icon(Icons.insert_drive_file, size: 48, color: Colors.grey));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E1F5)),
        ),
        child: Hero(
          tag: 'media_preview',
          child: Material(
            color: Colors.transparent,
            child: content,
          ),
        ),
      ),
    );
  }
}
