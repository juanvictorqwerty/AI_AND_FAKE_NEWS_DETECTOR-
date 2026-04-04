import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as ProcessingScreen)
const _redBg = Color(0xFFFEF2F2);
const _redBorder = Color(0xFFFECACA);
const _redText = Color(0xFFDC2626);

/// Retry row widget for ProcessingScreen
class RetryRow extends StatelessWidget {
  const RetryRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _redBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _redBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _redText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Something went wrong. You can retry or go back.',
              style: GoogleFonts.dmSans(fontSize: 13, color: _redText),
            ),
          ),
        ],
      ),
    );
  }
}
