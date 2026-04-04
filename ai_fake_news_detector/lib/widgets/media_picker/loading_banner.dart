import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as MediaPickerPage)
const _surface2 = Color(0xFFFFFFFF);
const _border = Color(0xFFE4E1F5);
const _textMuted = Color(0xFF7B78A0);
const _accent = Color.fromARGB(255, 17, 101, 235);

/// Loading banner widget for MediaPickerPage
class LoadingBanner extends StatelessWidget {
  const LoadingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Processing media…',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
