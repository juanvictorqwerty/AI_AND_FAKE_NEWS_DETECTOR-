import 'dart:io';
import 'package:flutter/material.dart';

// Design tokens (same as ProcessingScreen)
const _surface3 = Color(0xFFF0EEF9);
const _textMuted = Color(0xFF7B78A0);

/// File thumbnail widget for ProcessingScreen
class FileThumb extends StatelessWidget {
  final String? filePath;
  final String? fileType;

  const FileThumb({super.key, this.filePath, this.fileType});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 200,
        child: filePath != null && fileType == 'image'
            ? Image.file(
                File(filePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _videoPlaceholder(),
              )
            : _videoPlaceholder(),
      ),
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      color: _surface3,
      child: const Center(
        child: Icon(Icons.videocam_outlined, color: _textMuted, size: 48),
      ),
    );
  }
}
