import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';
import 'package:ai_fake_news_detector/models/analysis_result.dart';
import 'package:ai_fake_news_detector/models/video_frame_result.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/media_preview_widget.dart';
import 'package:ai_fake_news_detector/widgets/file_info_widget.dart';
import 'package:ai_fake_news_detector/widgets/analysis_result_widget.dart';
import 'package:ai_fake_news_detector/widgets/video_frame_result_widget.dart';
import 'package:ai_fake_news_detector/widgets/action_buttons_widget.dart';

/// Displays the media preview and the analysis result.
///
/// Route arguments (all provided by ProcessingScreen via pushReplacementNamed):
/// ```dart
/// {
///   'filePath'      : String,
///   'fileType'      : String,
///   'fileSize'      : int,
///   'videoDuration' : int?,
///   'taskId'        : String,
///   'status'        : String,   // 'completed' | 'failed'
///   'label'         : String?,
///   'confidence'    : double?,
///   'probabilities' : Map?,
///   'processingTime': dynamic?,
///   'fileId'        : String?,
///   'error'         : String?,
/// }
/// ```
class MediaResultPage extends StatefulWidget {
  const MediaResultPage({super.key});

  @override
  State<MediaResultPage> createState() => _MediaResultPageState();
}

class _MediaResultPageState extends State<MediaResultPage> {
  String? _filePath;
  String? _fileType;
  int? _fileSize;
  int? _videoDuration;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;

  AnalysisResult? _analysisResult;
  VideoFrameResult? _videoFrameResult;
  // Fix 4 – start as true only when there is no result in the args yet.
  bool _isLoading = true;
  String? _error;
  String? _taskId;

  // Named callbacks for clean removal (Fix 1).
  late final void Function(Map<String, dynamic>) _onResult;
  late final void Function(Map<String, dynamic>) _onError;
  bool _listenerRegistered = false;

  @override
  void initState() {
    super.initState();
    // Route arguments are available after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeMedia());
  }

  /// Read route arguments and decide whether we already have a result.
  Future<void> _initializeMedia() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null) {
      // No arguments at all – stay in loading and wait for the channel.
      _registerListeners();
      return;
    }

    setState(() {
      _filePath = args['filePath'] as String?;
      _fileType = args['fileType'] as String?;
      _fileSize = args['fileSize'] as int?;
      _videoDuration = args['videoDuration'] as int?;
      _taskId = args['taskId'] as String?;
    });

    // Fix 2 & Fix 4 – if the args already carry a completed result, use it
    // immediately.  Do NOT register a channel listener that will never fire.
    final status = args['status'] as String?;
    if (status == 'completed') {
      // Check if this is a video frame result
      if (args.containsKey('frame_count') && args.containsKey('frames')) {
        setState(() {
          _videoFrameResult = VideoFrameResult.fromJson(args);
          _isLoading = false;
        });
      } else {
        setState(() {
          _analysisResult = AnalysisResult.fromJson(args);
          _isLoading = false;
        });
      }
    } else if (status == 'failed') {
      setState(() {
        _error = args['error'] as String? ?? 'Analysis failed';
        _isLoading = false;
      });
    } else {
      // Result not yet available – subscribe to the channel as a fallback.
      _registerListeners();
    }

    // Initialise video player regardless of result state.
    if (_fileType == 'video' && _filePath != null) {
      _videoController = VideoPlayerController.file(File(_filePath!));
      await _videoController!.initialize();
      if (mounted) setState(() {});
    }
  }

  /// Fix 1 – register named callbacks so they can be removed precisely.
  void _registerListeners() {
    _onResult = (resultData) {
      // Ignore results meant for a different task.
      if (_taskId != null && resultData['taskId'] != _taskId) return;
      if (mounted) {
        setState(() {
          _analysisResult = AnalysisResult.fromJson(resultData);
          _isLoading = false;
        });
      }
    };

    _onError = (errorData) {
      if (_taskId != null && errorData['taskId'] != _taskId) return;
      if (mounted) {
        setState(() {
          _error = errorData['error'] as String? ?? 'Unknown error occurred';
          _isLoading = false;
        });
      }
    };

    MediaAnalysisChannel.addOnAnalysisResult(_onResult);
    MediaAnalysisChannel.addOnAnalysisError(_onError);
    _listenerRegistered = true;
  }

  @override
  void dispose() {
    _videoController?.dispose();
    if (_listenerRegistered) {
      MediaAnalysisChannel.removeOnAnalysisResult(_onResult);
      MediaAnalysisChannel.removeOnAnalysisError(_onError);
    }
    super.dispose();
  }

  void _toggleVideoPlayback() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isVideoPlaying = false;
      } else {
        _videoController!.play();
        _isVideoPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _analysisResult != null;
    final hasError = _error != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlobalColors.mainColor,
        title: const Text(
          'Analysis Result',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MediaPreviewWidget(
              filePath: _filePath,
              fileType: _fileType,
              videoController: _videoController,
              isVideoPlaying: _isVideoPlaying,
              onTogglePlayback: _toggleVideoPlayback,
            ),
            FileInfoWidget(
              filePath: _filePath,
              fileType: _fileType,
              fileSize: _fileSize,
              videoDuration: _videoDuration,
            ),
            if (_videoFrameResult != null)
              VideoFrameResultWidget(result: _videoFrameResult)
            else
              AnalysisResultWidget(
                isLoading: _isLoading,
                error: _error,
                result: _analysisResult,
              ),
            ActionButtonsWidget(
              filePath: _filePath,
              fileType: _fileType,
              fileSize: _fileSize,
              hasResult: hasResult,
              hasError: hasError,
            ),
          ],
        ),
      ),
    );
  }
}
