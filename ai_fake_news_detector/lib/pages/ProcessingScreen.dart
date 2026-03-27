import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';

/// Screen for showing upload progress and processing status
///
/// This screen displays:
/// - Upload progress indicator
/// - Processing status message
/// - File preview (image/video)
/// - Cancel button
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  VideoPlayerController? _videoController;
  bool _hasNavigated = false;
  bool _isDisposed = false;
  String? _taskId;
  String? _status;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVideoController();
    _setupStateListener();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _videoController?.dispose();
    super.dispose();
  }

  /// Setup listener for state changes
  void _setupStateListener() {
    MediaAnalysisChannel.setOnAnalysisResult((resultData) {
      if (!_hasNavigated && mounted && !_isDisposed) {
        _hasNavigated = true;
        // Navigate to result page
        Navigator.pushReplacementNamed(context, '/media-result');
      }
    });
    
    MediaAnalysisChannel.setOnAnalysisError((errorData) {
      if (mounted && !_isDisposed) {
        setState(() {
          _status = 'failed';
        });
      }
    });
  }

  /// Initialize video controller if file is a video
  Future<void> _initializeVideoController() async {
    // Video controller initialization will be handled by the page that navigates here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlobalColors.mainColor,
        title: const Text(
          'Processing',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _showCancelDialog(),
        ),
      ),
      body: Obx(() => _buildBody()),
    );
  }

  /// Build main body content
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File preview
          _buildFilePreview(),
          
          const SizedBox(height: 24),
          
          // Progress indicator
          _buildProgressIndicator(),
          
          const SizedBox(height: 16),
          
          // Status message
          _buildStatusMessage(),
          
          const SizedBox(height: 24),
          
          // Cancel button
          _buildCancelButton(),
        ],
      ),
    );
  }

  /// Build file preview widget
  Widget _buildFilePreview() {
    // File preview will be handled by the page that navigates here
    return const SizedBox.shrink();
  }

  /// Build progress indicator widget
  Widget _buildProgressIndicator() {
    if (_status == 'uploading') {
      // Show linear progress for upload
      return Column(
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(GlobalColors.mainColor),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: GlobalColors.mainColor,
            ),
          ),
        ],
      );
    } else if (_status == 'processing') {
      // Show circular progress for processing
      return Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(GlobalColors.mainColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Processing...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GlobalColors.mainColor,
            ),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  /// Build status message widget
  Widget _buildStatusMessage() {
    final message = _status ?? 'Ready to upload';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_status == 'uploading' || _status == 'processing')
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(GlobalColors.mainColor),
                ),
              ),
            ),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Build cancel button widget
  Widget _buildCancelButton() {
    return ElevatedButton(
      onPressed: (_status == 'uploading' || _status == 'processing') ? () => _showCancelDialog() : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[400],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Cancel',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Show cancel confirmation dialog
  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cancel Upload?'),
            ],
          ),
          content: const Text(
            'Are you sure you want to cancel the upload? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Cancel the analysis using Kotlin service
                if (_taskId != null) {
                  MediaAnalysisChannel.cancelAnalysis(_taskId!);
                }
                Navigator.pop(context); // Go back to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Upload'),
            ),
          ],
        );
      },
    );
  }
}
