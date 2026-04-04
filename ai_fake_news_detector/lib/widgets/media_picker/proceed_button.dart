import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as MediaPickerPage)
const _accent = Color.fromARGB(255, 17, 101, 235);
const _accent2 = Color.fromARGB(255, 18, 154, 226);

/// Proceed button widget for MediaPickerPage
class ProceedButton extends StatefulWidget {
  final VoidCallback onPressed;

  const ProceedButton({super.key, required this.onPressed});

  @override
  State<ProceedButton> createState() => _ProceedButtonState();
}

class _ProceedButtonState extends State<ProceedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _btnAnim;
  late final Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _btnAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _btnScale = Tween<double>(
      begin: 1,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _btnAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _btnAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _btnAnim.forward(),
      onTapUp: (_) {
        _btnAnim.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _btnAnim.reverse(),
      child: ScaleTransition(
        scale: _btnScale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_accent, _accent2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(.28),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'Upload & Analyse',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: .4,
            ),
          ),
        ),
      ),
    );
  }
}
