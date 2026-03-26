import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_fake_news_detector/services/media_picker_service.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';

/// Page for displaying the selected media file
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
/// - Option to upload or process the file
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
  
  @override
  void initState() {
    super.initState();
    // Initialize video controller if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMedia();
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
  
  /// Build action buttons
  Widget _buildActionButtons() {
    if (_filePath == null) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        const SizedBox(height: 24),
        BigButton(
          text: 'Upload to Server',
          onTap: () {
            // TODO: Implement upload functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Upload functionality coming soon!'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        BigButton(
          text: 'Pick Another File',
          onTap: () {
            Navigator.pop(context);
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
          'Selected Media',
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
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}
