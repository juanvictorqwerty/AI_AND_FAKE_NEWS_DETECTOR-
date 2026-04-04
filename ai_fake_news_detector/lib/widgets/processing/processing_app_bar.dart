import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as ProcessingScreen)
const _surface2 = Color(0xFFFFFFFF);
const _border = Color(0xFFE4E1F5);
const _textPrimary = Color(0xFF1A1730);

/// App bar widget for ProcessingScreen
class ProcessingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isActive;
  final VoidCallback onBackPressed;
  final VoidCallback onCancelPressed;

  const ProcessingAppBar({
    super.key,
    required this.isActive,
    required this.onBackPressed,
    required this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _surface2,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _textPrimary,
          size: 20,
        ),
        onPressed: isActive ? onCancelPressed : onBackPressed,
      ),
      title: Text(
        'Analysing',
        style: GoogleFonts.syne(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}
