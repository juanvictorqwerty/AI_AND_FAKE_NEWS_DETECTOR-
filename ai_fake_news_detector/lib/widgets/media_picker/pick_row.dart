import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as MediaPickerPage)
const _surface2 = Color(0xFFFFFFFF);
const _border = Color(0xFFE4E1F5);
const _textMuted = Color(0xFF7B78A0);
const _accent = Color.fromARGB(255, 17, 101, 235);

/// Pick row widget for MediaPickerPage
class PickRow extends StatelessWidget {
  final String activeType;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onPickMedia;

  const PickRow({
    super.key,
    required this.activeType,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onPickMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _pickButton(
            label: 'Image',
            icon: Icons.image_outlined,
            type: 'image',
            onTap: onPickImage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pickButton(
            label: 'Video',
            icon: Icons.videocam_outlined,
            type: 'video',
            onTap: onPickVideo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pickButton(
            label: 'Any',
            icon: Icons.perm_media_outlined,
            type: 'any',
            onTap: onPickMedia,
          ),
        ),
      ],
    );
  }

  Widget _pickButton({
    required String label,
    required IconData icon,
    required String type,
    required VoidCallback onTap,
  }) {
    final active = activeType == type;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFAF8FF) : _surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? _accent : _border, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: active ? _accent : _textMuted),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? _accent : _textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
