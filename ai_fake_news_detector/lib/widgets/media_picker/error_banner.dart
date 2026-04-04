import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as MediaPickerPage)
const _errorBg = Color(0xFFFEF2F2);
const _errorBorder = Color(0xFFFECACA);
const _errorText = Color(0xFFDC2626);

/// Error banner widget for MediaPickerPage
class ErrorBanner extends StatelessWidget {
  final String? errorMessage;

  const ErrorBanner({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _errorText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: GoogleFonts.dmSans(fontSize: 13, color: _errorText),
            ),
          ),
        ],
      ),
    );
  }
}
