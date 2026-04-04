import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (same as ProcessingScreen)
const _surface2 = Color(0xFFFFFFFF);
const _surface3 = Color(0xFFF0EEF9);
const _border = Color(0xFFE4E1F5);
const _textPrimary = Color(0xFF1A1730);
const _textMuted = Color(0xFF7B78A0);
const _green = Color(0xFF16A34A);
const _greenBg = Color(0xFFF0FDF4);
const _greenBorder = Color(0xFFBBF7D0);
const _redBg = Color(0xFFFEF2F2);
const _redBorder = Color(0xFFFECACA);
const _redText = Color(0xFFDC2626);
const _accent = Color.fromARGB(255, 15, 162, 241);

/// Stage card widget for ProcessingScreen
class StageCard extends StatelessWidget {
  final String status;
  final double progress;

  const StageCard({super.key, required this.status, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _stageRow(
            index: 0,
            name: 'File validated',
            sub: 'Format & integrity check passed',
            stageKey: 'validated',
          ),
          _stageDivider(),
          _stageRow(
            index: 1,
            name: status == 'uploading'
                ? 'Uploading to server'
                : 'Upload complete',
            sub: status == 'uploading'
                ? 'Securely transmitting file'
                : 'File received by server',
            stageKey: 'uploading',
            showProgress: status == 'uploading' || status == 'uploading_frames',
          ),
          _stageDivider(),
          _stageRow(
            index: 2,
            name: 'AI analysis',
            sub: 'Deep-fake & manipulation detection',
            stageKey: 'processing',
          ),
          _stageDivider(),
          _stageRow(
            index: 3,
            name: 'Results ready',
            sub: 'Report generated',
            stageKey: 'done',
          ),
        ],
      ),
    );
  }

  // Stage ordering: validated(0) → uploading(1) → processing(2) → done(3)
  _StageState _stageState(int index) {
    final order = {
      'uploading': 1,
      'uploading_frames': 1,
      'extracting_frames': 1,
      'processing': 2,
      'failed': 2,
      'done': 3,
      'cancelled': 0,
    };
    final current = order[status] ?? 0;
    if (index == 0) return _StageState.done; // validated always done
    if (index < current) return _StageState.done;
    if (index == current) {
      return status == 'failed' ? _StageState.error : _StageState.active;
    }
    return _StageState.waiting;
  }

  Widget _stageDivider() => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    height: 1,
    color: _border,
  );

  Widget _stageRow({
    required int index,
    required String name,
    required String sub,
    required String stageKey,
    bool showProgress = false,
  }) {
    final state = _stageState(index);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stageDot(state),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: state == _StageState.done
                      ? _green
                      : state == _StageState.active
                      ? _textPrimary
                      : state == _StageState.error
                      ? _redText
                      : _textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted),
              ),
              if (showProgress) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: _surface3,
                    valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.dmSans(fontSize: 11, color: _textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stageDot(_StageState state) {
    switch (state) {
      case _StageState.done:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _greenBg,
            shape: BoxShape.circle,
            border: Border.all(color: _greenBorder, width: 1.5),
          ),
          child: const Icon(Icons.check_rounded, color: _green, size: 16),
        );
      case _StageState.active:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEFF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC4B5FD), width: 1.5),
          ),
          child: const Icon(Icons.autorenew_rounded, color: _accent, size: 16),
        );
      case _StageState.error:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _redBg,
            shape: BoxShape.circle,
            border: Border.all(color: _redBorder, width: 1.5),
          ),
          child: const Icon(Icons.close_rounded, color: _redText, size: 16),
        );
      case _StageState.waiting:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _surface3,
            shape: BoxShape.circle,
            border: Border.all(color: _border, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFCCC8EE),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
    }
  }
}

enum _StageState { done, active, waiting, error }
