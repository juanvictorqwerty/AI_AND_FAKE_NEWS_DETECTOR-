import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as ProcessingScreen)
const _surface2 = Color(0xFFFFFFFF);
const _border = Color(0xFFE4E1F5);
const _textMuted = Color(0xFF7B78A0);
const _accent = Color.fromARGB(255, 15, 162, 241);

/// Stats row widget for ProcessingScreen
class StatsRow extends StatelessWidget {
  final double progress;
  final int frameCount;

  const StatsRow({super.key, required this.progress, required this.frameCount});

  @override
  Widget build(BuildContext context) {
    final pct = '${(progress * 100).toStringAsFixed(0)}%';
    return Row(
      children: [
        Expanded(
          child: _statCard(value: pct, label: 'Upload progress'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            value: frameCount > 0 ? '$frameCount' : '—',
            label: frameCount > 0 ? 'Frames' : 'File size',
          ),
        ),
      ],
    );
  }

  Widget _statCard({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 11, color: _textMuted),
          ),
        ],
      ),
    );
  }
}
