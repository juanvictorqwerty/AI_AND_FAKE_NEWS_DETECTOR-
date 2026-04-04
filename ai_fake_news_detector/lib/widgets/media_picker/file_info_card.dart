import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_fake_news_detector/services/media_picker_service.dart';

// Design tokens (same as MediaPickerPage)
const _surface2 = Color(0xFFFFFFFF);
const _border = Color(0xFFE4E1F5);
const _textPrimary = Color(0xFF1A1730);
const _textMuted = Color(0xFF7B78A0);

/// File info card widget for MediaPickerPage
class FileInfoCard extends StatelessWidget {
  final String? selectedFilePath;
  final String? fileType;
  final int? fileSize;
  final int? videoDuration;
  final MediaPickerService mediaPickerService;

  const FileInfoCard({
    super.key,
    required this.selectedFilePath,
    required this.fileType,
    required this.fileSize,
    required this.videoDuration,
    required this.mediaPickerService,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedFilePath == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          if (fileType != null)
            _infoRow(
              label: 'File type',
              value: fileType == 'image' ? 'Image' : 'Video',
            ),
          if (fileSize != null)
            _infoRow(
              label: 'Size',
              value: mediaPickerService.getFileSizeFormatted(fileSize!),
            ),
          if (videoDuration != null)
            _infoRow(
              label: 'Duration',
              value: mediaPickerService.getDurationFormatted(videoDuration!),
              isLast: true,
            ),
          if (videoDuration == null && fileSize != null)
            _infoRow(
              label: 'File path',
              value: selectedFilePath!.split('/').last,
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
