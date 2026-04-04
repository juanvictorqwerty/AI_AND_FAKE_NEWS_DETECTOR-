import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';

// ─── Design tokens (same palette as MediaPickerPage) ─────────────────────────
const _accent = Color.fromARGB(255, 15, 162, 241);
const _surface = Color(0xFFF7F6FF);
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

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  bool _hasNavigated = false;
  bool _isDisposed = false;

  String? _taskId;
  String? _filePath;
  String? _fileType;

  String _status = 'uploading';
  double _progress = 0.0;
  int _frameCount = 0;

  late final AnimationController _spinCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  late final void Function(Map<String, dynamic>) _onResult;
  late final void Function(Map<String, dynamic>) _onError;
  late final void Function(Map<String, dynamic>) _onVideoFrameResult;
  late final void Function(Map<String, dynamic>) _onVideoFrameError;
  late final void Function(Map<String, dynamic>) _onVideoFrameProgress;
  StreamSubscription<AnalysisProgressEvent>? _progressSub;

  @override
  void initState() {
    super.initState();

    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0, end: 6).animate(_pulseCtrl);

    _onResult = (resultData) {
      if (!_hasNavigated && mounted && !_isDisposed) {
        _hasNavigated = true;
        Navigator.pushReplacementNamed(context, '/media-result', arguments: {
          'filePath': _filePath,
          'fileType': _fileType,
          ...resultData,
        });
      }
    };
    _onError = (errorData) {
      if (mounted && !_isDisposed) setState(() => _status = 'failed');
    };
    _onVideoFrameResult = (resultData) {
      if (!_hasNavigated && mounted && !_isDisposed) {
        _hasNavigated = true;
        Navigator.pushReplacementNamed(context, '/media-result', arguments: {
          'filePath': _filePath,
          'fileType': _fileType,
          ...resultData,
        });
      }
    };
    _onVideoFrameError = (errorData) {
      if (mounted && !_isDisposed) setState(() => _status = 'failed');
    };
    _onVideoFrameProgress = (progressData) {
      if (mounted && !_isDisposed) {
        setState(() {
          _status = progressData['status'] as String? ?? _status;
          _progress =
              (progressData['progress'] as num?)?.toDouble() ?? _progress;
          _frameCount = progressData['frameCount'] as int? ?? _frameCount;
        });
      }
    };

    MediaAnalysisChannel.addOnAnalysisResult(_onResult);
    MediaAnalysisChannel.addOnAnalysisError(_onError);
    MediaAnalysisChannel.addOnVideoFrameResult(_onVideoFrameResult);
    MediaAnalysisChannel.addOnVideoFrameError(_onVideoFrameError);
    MediaAnalysisChannel.addOnVideoFrameProgress(_onVideoFrameProgress);

    _progressSub = MediaAnalysisChannel.progressStream.listen((event) {
      if (!mounted || _isDisposed) return;
      if (event.taskId != _taskId) return;
      setState(() {
        _status = event.status;
        _progress = event.progress;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _readArgs());
  }

  void _readArgs() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        _taskId = args['taskId'] as String?;
        _filePath = args['filePath'] as String?;
        _fileType = args['fileType'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    MediaAnalysisChannel.removeOnAnalysisResult(_onResult);
    MediaAnalysisChannel.removeOnAnalysisError(_onError);
    MediaAnalysisChannel.removeOnVideoFrameResult(_onVideoFrameResult);
    MediaAnalysisChannel.removeOnVideoFrameError(_onVideoFrameError);
    MediaAnalysisChannel.removeOnVideoFrameProgress(_onVideoFrameProgress);
    _progressSub?.cancel();
    super.dispose();
  }

  bool get _isActive =>
      ['uploading', 'extracting_frames', 'uploading_frames', 'processing']
          .contains(_status);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildFileThumb(),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 4),
          _buildStageCard(),
          const SizedBox(height: 16),
          if (_status == 'failed') _buildRetryRow(),
          if (_isActive) _buildCancelButton(),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface2,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textPrimary, size: 20),
        onPressed: _isActive ? _showCancelDialog : () => Navigator.pop(context),
      ),
      title: Text('Analysing',
          style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary)),
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border)),
    );
  }

  // ── File thumbnail ────────────────────────────────────────────────────────

  Widget _buildFileThumb() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 200,
        child: _filePath != null && _fileType == 'image'
            ? Image.file(File(_filePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _videoPlaceholder())
            : _videoPlaceholder(),
      ),
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      color: _surface3,
      child: const Center(
          child: Icon(Icons.videocam_outlined, color: _textMuted, size: 48)),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final pct = '${(_progress * 100).toStringAsFixed(0)}%';
    return Row(children: [
      Expanded(child: _statCard(value: pct, label: 'Upload progress')),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard(
              value: _frameCount > 0 ? '$_frameCount' : '—',
              label: _frameCount > 0 ? 'Frames' : 'File size')),
    ]);
  }

  Widget _statCard({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: GoogleFonts.syne(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _accent)),
        const SizedBox(height: 4),
        Text(label,
            style:
                GoogleFonts.dmSans(fontSize: 11, color: _textMuted)),
      ]),
    );
  }

  // ── Stage card ────────────────────────────────────────────────────────────

  Widget _buildStageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        _stageRow(
          index: 0,
          name: 'File validated',
          sub: 'Format & integrity check passed',
          stageKey: 'validated',
        ),
        _stageDivider(),
        _stageRow(
          index: 1,
          name: _status == 'uploading'
              ? 'Uploading to server'
              : 'Upload complete',
          sub: _status == 'uploading'
              ? 'Securely transmitting file'
              : 'File received by server',
          stageKey: 'uploading',
          showProgress: _status == 'uploading' || _status == 'uploading_frames',
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
      ]),
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
    final current = order[_status] ?? 0;
    if (index == 0) return _StageState.done; // validated always done
    if (index < current) return _StageState.done;
    if (index == current) {
      return _status == 'failed'
          ? _StageState.error
          : _StageState.active;
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
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stageDot(state),
      const SizedBox(width: 14),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(name,
                style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: state == _StageState.done
                        ? _green
                        : state == _StageState.active
                            ? _textPrimary
                            : state == _StageState.error
                                ? _redText
                                : _textMuted)),
            const SizedBox(height: 3),
            Text(sub,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: _textMuted)),
            if (showProgress) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 4,
                  backgroundColor: _surface3,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_accent),
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: _textMuted),
                ),
              ),
            ],
          ])),
    ]);
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
              border: Border.all(color: _greenBorder, width: 1.5)),
          child: const Icon(Icons.check_rounded, color: _green, size: 16),
        );
      case _StageState.active:
        return AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC4B5FD), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _accent.withOpacity(.25),
                    blurRadius: _pulseAnim.value,
                    spreadRadius: _pulseAnim.value * .4),
              ],
            ),
            child: RotationTransition(
              turns: _spinCtrl,
              child: const Icon(Icons.autorenew_rounded,
                  color: _accent, size: 16),
            ),
          ),
        );
      case _StageState.error:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: _redBg,
              shape: BoxShape.circle,
              border: Border.all(color: _redBorder, width: 1.5)),
          child: const Icon(Icons.close_rounded, color: _redText, size: 16),
        );
      case _StageState.waiting:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: _surface3,
              shape: BoxShape.circle,
              border: Border.all(color: _border, width: 1.5)),
          child: Center(
              child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFFCCC8EE),
                      shape: BoxShape.circle))),
        );
    }
  }

  // ── Retry / cancel ────────────────────────────────────────────────────────

  Widget _buildRetryRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _redBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _redBorder),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: _redText, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Something went wrong. You can retry or go back.',
                style:
                    GoogleFonts.dmSans(fontSize: 13, color: _redText))),
      ]),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: _showCancelDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _redBorder, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text('Cancel analysis',
            style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _redText,
                letterSpacing: .3)),
      ),
    );
  }

  // ── Cancel dialog ─────────────────────────────────────────────────────────

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          Text('Cancel Upload?',
              style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
        ]),
        content: Text(
          'Are you sure you want to cancel? This action cannot be undone.',
          style: GoogleFonts.dmSans(fontSize: 14, color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Continue',
                style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_taskId != null) {
                MediaAnalysisChannel.cancelAnalysis(_taskId!);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _redText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Cancel Upload',
                style: GoogleFonts.syne(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

enum _StageState { done, active, waiting, error }