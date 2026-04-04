import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

// Design tokens (same as MediaPickerPage)
const _surface2 = Color(0xFFFFFFFF);
const _surface3 = Color(0xFFF0EEF9);
const _border2 = Color(0xFFCCC8EE);
const _textPrimary = Color(0xFF1A1730);
const _textMuted = Color(0xFF7B78A0);
const _accent = Color.fromARGB(255, 17, 101, 235);

/// Drop zone widget for media preview in MediaPickerPage
class DropZone extends StatefulWidget {
  final String? selectedFilePath;
  final String? fileType;
  final VideoPlayerController? videoController;
  final VoidCallback? onTap;

  const DropZone({
    super.key,
    this.selectedFilePath,
    this.fileType,
    this.videoController,
    this.onTap,
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  @override
  Widget build(BuildContext context) {
    final hasFile = widget.selectedFilePath != null;
    return GestureDetector(
      onTap: hasFile ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: hasFile ? 240 : 180,
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasFile ? _accent : _border2,
            width: hasFile ? 1.5 : 1.5,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: hasFile ? _buildPreviewContent() : _buildEmptyDrop(),
      ),
    );
  }

  Widget _buildEmptyDrop() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _surface3,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.upload_rounded,
              color: _textMuted,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Drop file here or tap to browse',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'PNG, JPG, MP4, MOV · up to 100 MB',
            style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (widget.fileType == 'image') {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(widget.selectedFilePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: _textMuted,
                size: 48,
              ),
            ),
          ),
          // bottom gradient + badge
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC1A1730), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  _typeBadge('Image'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.selectedFilePath!.split('/').last,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (widget.fileType == 'video') {
      if (widget.videoController != null &&
          widget.videoController!.value.isInitialized) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: widget.videoController!.value.aspectRatio,
              child: VideoPlayer(widget.videoController!),
            ),
            GestureDetector(
              onTap: () => setState(() {
                widget.videoController!.value.isPlaying
                    ? widget.videoController!.pause()
                    : widget.videoController!.play();
              }),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.videoController!.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: _accent,
                  size: 28,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC1A1730), Colors.transparent],
                  ),
                ),
                child: Row(children: [_typeBadge('Video')]),
              ),
            ),
          ],
        );
      }
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_accent),
          strokeWidth: 2.5,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _typeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _accent.withOpacity(.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.syne(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF3EEFF),
          letterSpacing: .8,
        ),
      ),
    );
  }
}
