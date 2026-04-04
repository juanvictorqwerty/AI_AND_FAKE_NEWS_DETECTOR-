import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as ProcessingScreen)
const _redBorder = Color(0xFFFECACA);
const _redText = Color(0xFFDC2626);

/// Cancel button widget for ProcessingScreen
class CancelButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CancelButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _redBorder, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          'Cancel analysis',
          style: GoogleFonts.syne(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _redText,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}
