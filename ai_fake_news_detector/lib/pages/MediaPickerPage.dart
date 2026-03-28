import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_fake_news_detector/services/media_picker_service.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';

/// Page for picking and previewing media files (images and videos)
///
/// This page provides:
/// - Buttons to pick image, video, or any media
/// - Preview of selected file
/// - File metadata display (size, duration)
/// - Loading indicators
/// - Error messages
/// - Navigation to processing and result pages
class MediaPickerPage extends StatefulWidget {
  const MediaPickerPage({super.key});

  @override
  State<MediaPickerPage> createState() => _MediaPickerPageState();
}

class _MediaPickerPageState extends State<MediaPickerPage> {
  final MediaPickerService _mediaPickerService = Get.find<MediaPickerService>();
  
  // State variables
  bool _isLoading = false;
  String? _selectedFilePath;
  String? _fileType;
  int? _fileSize;
  int? _videoDuration;
  String? _errorMessage;
  VideoPlayerController? _videoController;
  
  @override
  void dispose() {
    // Clean up video controller when page is disposed
    _videoController?.dispose();
    super.dispose();
  }
  
  /// Pick an image from gallery
  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFilePath = null;
      _fileType = null;
      _fileSize = null;
      _videoDuration = null;
    });
    
    try {
      final result = await _mediaPickerService.pickImage();
      
      if (result['success']) {
        setState(() {
          _selectedFilePath = result['filePath'];
          _fileType = result['fileType'];
          _fileSize = result['fileSize'];
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
        
        // Show settings dialog if permission is permanently denied
        if (result['permanentlyDenied'] == true) {
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Pick a video from gallery
  Future<void> _pickVideo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFilePath = null;
      _fileType = null;
      _fileSize = null;
      _videoDuration = null;
    });
    
    // Dispose previous video controller if exists
    await _videoController?.dispose();
    _videoController = null;
    
    try {
      final result = await _mediaPickerService.pickVideo();
      
      if (result['success']) {
        setState(() {
          _selectedFilePath = result['filePath'];
          _fileType = result['fileType'];
          _fileSize = result['fileSize'];
          _videoDuration = result['duration'];
          _errorMessage = null;
        });
        
        // Initialize video controller for preview
        if (_fileType == 'video' && _selectedFilePath != null) {
          _videoController = VideoPlayerController.file(File(_selectedFilePath!));
          await _videoController!.initialize();
          setState(() {});
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
        
        // Show settings dialog if permission is permanently denied
        if (result['permanentlyDenied'] == true) {
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking video: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Pick any media (image or video) from gallery
  Future<void> _pickMedia() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFilePath = null;
      _fileType = null;
      _fileSize = null;
      _videoDuration = null;
    });
    
    // Dispose previous video controller if exists
    await _videoController?.dispose();
    _videoController = null;
    
    try {
      final result = await _mediaPickerService.pickMedia();
      
      if (result['success']) {
        setState(() {
          _selectedFilePath = result['filePath'];
          _fileType = result['fileType'];
          _fileSize = result['fileSize'];
          _videoDuration = result['duration'];
          _errorMessage = null;
        });
        
        // Initialize video controller for preview if video
        if (_fileType == 'video' && _selectedFilePath != null) {
          _videoController = VideoPlayerController.file(File(_selectedFilePath!));
          await _videoController!.initialize();
          setState(() {});
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
        
        // Show settings dialog if permission is permanently denied
        if (result['permanentlyDenied'] == true) {
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking media: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Show dialog when permission is permanently denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Permission Required'),
            ],
          ),
          content: const Text(
            'Storage permission has been permanently denied. '
            'Please enable it in app settings to access your gallery.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _mediaPickerService.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalColors.mainColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
  
  /// Navigate to processing screen and start upload
  void _proceedWithFile() {
    if (_selectedFilePath != null && _fileType != null) {
      // Start upload and processing using Kotlin service
      // startAnalysis generates its own taskId and returns it
      MediaAnalysisChannel.startAnalysis(_selectedFilePath!, _fileType!);
      
      // Navigate to processing screen
      Navigator.pushNamed(context, '/processing');
    }
  }
  
  /// Build media preview widget
  Widget _buildMediaPreview() {
    if (_selectedFilePath == null) {
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
                Icons.image_outlined,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No file selected',
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
            File(_selectedFilePath!),
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
                    _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 64,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
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
    if (_selectedFilePath == null) {
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
        ],
      ),
    );
  }
  
  /// Build error message widget
  Widget _buildErrorMessage() {
    if (_errorMessage == null) {
      return const SizedBox.shrink();
    }
    
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
          Icon(
            Icons.error_outline,
            color: Colors.red[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlobalColors.mainColor,
        title: const Text(
          'Upload Media',
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
            // Loading indicator
            if (_isLoading)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: GlobalColors.mainColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Processing media...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Media preview
            _buildMediaPreview(),
            
            // File info
            _buildFileInfo(),
            
            // Error message
            _buildErrorMessage(),
            
            const SizedBox(height: 24),
            
            // Pick buttons
            if (!_isLoading) ...[
              BigButton(
                text: 'Pick Image',
                onTap: _pickImage,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              BigButton(
                text: 'Pick Video',
                onTap: _pickVideo,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              BigButton(
                text: 'Pick Any Media',
                onTap: _pickMedia,
                color: GlobalColors.mainColor,
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Upload and Analyze button (only shown when file is selected)
            if (_selectedFilePath != null && !_isLoading)
              BigButton(
                text: 'Upload and Analyze',
                onTap: _proceedWithFile,
                color: Colors.deepPurpleAccent,
              ),
          ],
        ),
      ),
    );
  }
}
