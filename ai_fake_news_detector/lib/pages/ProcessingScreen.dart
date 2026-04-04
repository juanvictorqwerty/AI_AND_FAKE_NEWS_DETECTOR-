import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';
import 'package:ai_fake_news_detector/widgets/processing/processing_app_bar.dart';
import 'package:ai_fake_news_detector/widgets/processing/file_thumb.dart';
import 'package:ai_fake_news_detector/widgets/processing/stats_row.dart';
import 'package:ai_fake_news_detector/widgets/processing/stage_card.dart';
import 'package:ai_fake_news_detector/widgets/processing/retry_row.dart';
import 'package:ai_fake_news_detector/widgets/processing/cancel_button.dart';

// ─── Design tokens (same palette as MediaPickerPage) ─────────────────────────
const _surface = Color(0xFFF7F6FF);
const _textPrimary = Color(0xFF1A1730);
const _textMuted = Color(0xFF7B78A0);
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
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _onResult = (resultData) {
      if (!_hasNavigated && mounted && !_isDisposed) {
        _hasNavigated = true;
        Navigator.pushReplacementNamed(
          context,
          '/media-result',
          arguments: {
            'filePath': _filePath,
            'fileType': _fileType,
            ...resultData,
          },
        );
      }
    };
    _onError = (errorData) {
      if (mounted && !_isDisposed) setState(() => _status = 'failed');
    };
    _onVideoFrameResult = (resultData) {
      if (!_hasNavigated && mounted && !_isDisposed) {
        _hasNavigated = true;
        Navigator.pushReplacementNamed(
          context,
          '/media-result',
          arguments: {
            'filePath': _filePath,
            'fileType': _fileType,
            ...resultData,
          },
        );
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
    MediaAnalysisChannel.removeOnAnalysisResult(_onResult);
    MediaAnalysisChannel.removeOnAnalysisError(_onError);
    MediaAnalysisChannel.removeOnVideoFrameResult(_onVideoFrameResult);
    MediaAnalysisChannel.removeOnVideoFrameError(_onVideoFrameError);
    MediaAnalysisChannel.removeOnVideoFrameProgress(_onVideoFrameProgress);
    _progressSub?.cancel();
    super.dispose();
  }

  bool get _isActive => [
    'uploading',
    'extracting_frames',
    'uploading_frames',
    'processing',
  ].contains(_status);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: ProcessingAppBar(
        isActive: _isActive,
        onBackPressed: () => Navigator.pop(context),
        onCancelPressed: _showCancelDialog,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FileThumb(filePath: _filePath, fileType: _fileType),
            const SizedBox(height: 20),
            StatsRow(progress: _progress, frameCount: _frameCount),
            const SizedBox(height: 4),
            StageCard(status: _status, progress: _progress),
            const SizedBox(height: 16),
            if (_status == 'failed') const RetryRow(),
            if (_isActive) CancelButton(onPressed: _showCancelDialog),
          ],
        ),
      ),
    );
  }

  // ── Cancel dialog ─────────────────────────────────────────────────────────

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Cancel Upload?',
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel? This action cannot be undone.',
          style: GoogleFonts.dmSans(fontSize: 14, color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Continue',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textMuted,
              ),
            ),
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
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Cancel Upload',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
