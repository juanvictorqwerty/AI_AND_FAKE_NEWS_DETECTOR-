import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_fake_news_detector/services/media_picker_service.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';
import 'package:ai_fake_news_detector/models/analysis_result.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';

/// Page for displaying the selected media file and analysis results
///
/// This page receives:
/// - filePath: path to the selected file
/// - fileType: 'image' or 'video'
/// - fileSize: file size in bytes
/// - videoDuration: video duration in seconds (for videos only)
///
/// It displays:
/// - Preview of the file
/// - File metadata
/// - Analysis results (AI/Human label, confidence, probabilities)
/// - Option to upload new file or retry
class MediaResultPage extends StatefulWidget {
  const MediaResultPage({super.key});

  @override
  State<MediaResultPage> createState() => _MediaResultPageState();
}

class _MediaResultPageState extends State<MediaResultPage> {
  final MediaPickerService _mediaPickerService = Get.find<MediaPickerService>();
  
  // State variables
  String? _filePath;
  String? _fileType;
  int? _fileSize;
  int? _videoDuration;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  AnalysisResult? _analysisResult;
  bool _isLoading = true;
  String? _error;
  String? _taskId;
  
  @override
  void initState() {
    super.initState();
    // Initialize video controller if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMedia();
    });
    // Listen for analysis results
    _setupAnalysisListener();
  }
  
  /// Setup listener for analysis results from Kotlin service
  void _setupAnalysisListener() {
    MediaAnalysisChannel.setOnAnalysisResult((resultData) {
      if (mounted) {
        setState(() {
          _analysisResult = AnalysisResult.fromJson(resultData);
          _isLoading = false;
        });
      }
    });
    
    MediaAnalysisChannel.setOnAnalysisError((errorData) {
      if (mounted) {
        setState(() {
          _error = errorData['error'] ?? 'Unknown error occurred';
          _isLoading = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    // Clean up video controller when page is disposed
    _videoController?.dispose();
    super.dispose();
  }
  
  /// Initialize media based on arguments
  Future<void> _initializeMedia() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      setState(() {
        _filePath = args['filePath'];
        _fileType = args['fileType'];
        _fileSize = args['fileSize'];
        _videoDuration = args['videoDuration'];
      });
      
      // Initialize video controller if video
      if (_fileType == 'video' && _filePath != null) {
        _videoController = VideoPlayerController.file(File(_filePath!));
        await _videoController!.initialize();
        setState(() {});
      }
    }
  }
  
  /// Toggle video play/pause
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
  
  /// Build media preview widget
  Widget _buildMediaPreview() {
    if (_filePath == null) {
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
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No file provided',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
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
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading image',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red[400],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (_fileType == 'video') {
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
                // Play/Pause button
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
      } else {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Center(
            child: CircularProgressIndicator(
              color: GlobalColors.mainColor,
            ),
          ),
        );
      }
    }
    
    return const SizedBox.shrink();
  }
  
  /// Build file info widget
  Widget _buildFileInfo() {
    if (_filePath == null) {
      return const SizedBox.shrink();
    }
    
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
                _fileType == 'image' ? Icons.image : Icons.videocam,
                color: GlobalColors.mainColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _fileType == 'image' ? 'Image' : 'Video',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_fileSize != null)
            Row(
              children: [
                Icon(
                  Icons.file_present,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Size: ${_mediaPickerService.getFileSizeFormatted(_fileSize!)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          if (_videoDuration != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Duration: ${_mediaPickerService.getDurationFormatted(_videoDuration!)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'File validated successfully',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Build analysis result widget
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
        child: const Center(
          child: CircularProgressIndicator(),
        ),
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
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ],
        ),
      );
    }
    
    final result = _analysisResult;
    
    if (result == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.isAi ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isAi ? Colors.red[300]! : Colors.green[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label and confidence
          Row(
            children: [
              Icon(
                result.isAi ? Icons.smart_toy : Icons.person,
                color: result.isAi ? Colors.red[700] : Colors.green[700],
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
                        color: result.isAi ? Colors.red[700] : Colors.green[700],
                      ),
                    ),
                    Text(
                      'Confidence: ${result.confidencePercentage}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Probabilities
          _buildProbabilityBar('AI', result.aiProbability, Colors.red[400]!),
          const SizedBox(height: 8),
          _buildProbabilityBar('Human', result.humanProbability, Colors.green[400]!),
          
          const SizedBox(height: 16),
          
          // Error message if any
          if (result.hasError)
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
                    child: Text(
                      result.error!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  /// Build probability bar widget
  Widget _buildProbabilityBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
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
  
  /// Build action buttons
  Widget _buildActionButtons() {
    if (_filePath == null) {
      return const SizedBox.shrink();
    }
    
    final hasResult = _analysisResult != null;
    final hasError = _error != null;
    
    return Column(
      children: [
        const SizedBox(height: 24),
        
        // Show retry button if error
        if (hasError)
          BigButton(
            text: 'Retry Upload',
            onTap: () {
              _taskId = DateTime.now().millisecondsSinceEpoch.toString();
              MediaAnalysisChannel.startAnalysis(_filePath!, _fileType!, _taskId!);
              Navigator.pushNamed(context, '/processing');
            },
            color: Colors.orange,
          ),
        
        // Show upload new button if completed or no result
        if (hasResult || !hasError)
          BigButton(
            text: 'Upload New File',
            onTap: () {
              Navigator.pop(context);
            },
            color: Colors.green,
          ),
        
        const SizedBox(height: 12),
        
        // Back button
        BigButton(
          text: 'Back to Home',
          onTap: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
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
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
            // Media preview
            _buildMediaPreview(),
            
            // File info
            _buildFileInfo(),
            
            // Analysis result
            _buildAnalysisResult(),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}
