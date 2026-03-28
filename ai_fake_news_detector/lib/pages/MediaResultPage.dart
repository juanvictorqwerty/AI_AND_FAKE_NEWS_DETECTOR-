import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_fake_news_detector/services/media_picker_service.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';
import 'package:ai_fake_news_detector/models/analysis_result.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';

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
  final MediaPickerService _mediaPickerService = Get.find<MediaPickerService>();

  String? _filePath;
  String? _fileType;
  int? _fileSize;
  int? _videoDuration;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;

  AnalysisResult? _analysisResult;
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
    final args = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;

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
      setState(() {
        _analysisResult = AnalysisResult.fromJson(args);
        _isLoading = false;
      });
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

  Widget _buildMediaPreview() {
    if (_filePath == null) {
      return _placeholder(Icons.error_outline, 'No file provided');
    }

    if (_fileType == 'image') {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_filePath!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                _placeholder(Icons.error_outline, 'Error loading image',
                    color: Colors.red[400]),
          ),
        ),
      );
    }

    if (_fileType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                IconButton(
                  icon: Icon(
                    _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                    size: 64,
                    color: Colors.white,
                  ),
                  onPressed: _toggleVideoPlayback,
                ),
              ],
            ),
          ),
        );
      }
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Center(
            child: CircularProgressIndicator(color: GlobalColors.mainColor)),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _placeholder(IconData icon, String text, {Color? color}) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color ?? Colors.grey[600]),
            const SizedBox(height: 16),
            Text(text,
                style: TextStyle(
                    fontSize: 16, color: color ?? Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo() {
    if (_filePath == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _fileType == 'video' ? Icons.videocam : Icons.image,
                color: GlobalColors.mainColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _filePath!.split('/').last,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_fileSize != null) ...[
            const SizedBox(height: 8),
            Text('Size: ${(_fileSize! / 1024 / 1024).toStringAsFixed(2)} MB',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
          if (_videoDuration != null) ...[
            const SizedBox(height: 4),
            Text('Duration: ${_videoDuration}s',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text('File validated successfully',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_error!,
                    style: TextStyle(color: Colors.red[700]))),
          ],
        ),
      );
    }

    final result = _analysisResult;
    if (result == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.isAi ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: result.isAi ? Colors.red[300]! : Colors.green[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isAi ? Icons.smart_toy : Icons.person,
                color:
                    result.isAi ? Colors.red[700] : Colors.green[700],
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: result.isAi
                            ? Colors.red[700]
                            : Colors.green[700],
                      ),
                    ),
                    Text(
                      'Confidence: ${result.confidencePercentage}',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProbabilityBar(
              'AI', result.aiProbability, Colors.red[400]!),
          const SizedBox(height: 8),
          _buildProbabilityBar(
              'Human', result.humanProbability, Colors.green[400]!),
          if (result.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(result.error!,
                          style: TextStyle(color: Colors.red[700]))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProbabilityBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            Text('${(value * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_filePath == null) return const SizedBox.shrink();

    final hasResult = _analysisResult != null;
    final hasError = _error != null;

    return Column(
      children: [
        const SizedBox(height: 24),
        if (hasError)
          BigButton(
            text: 'Retry Upload',
            onTap: () async {
              // Fix 6 – startAnalysis returns the taskId.
              final taskId = await MediaAnalysisChannel.startAnalysis(
                  _filePath!, _fileType!);
              Navigator.pushNamed(
                context,
                '/processing',
                arguments: {
                  'filePath': _filePath,
                  'fileType': _fileType,
                  'fileSize': _fileSize,
                  'taskId': taskId,
                },
              );
            },
            color: Colors.orange,
          ),
        if (hasResult || !hasError)
          BigButton(
            text: 'Upload New File',
            onTap: () => Navigator.pop(context),
            color: Colors.green,
          ),
        const SizedBox(height: 12),
        BigButton(
          text: 'Back to Home',
          onTap: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
          color: Colors.grey[600]!,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlobalColors.mainColor,
        title: const Text(
          'Analysis Result',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
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
            _buildMediaPreview(),
            _buildFileInfo(),
            _buildAnalysisResult(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}