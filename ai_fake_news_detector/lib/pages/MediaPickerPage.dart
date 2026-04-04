import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_fake_news_detector/services/media_picker_service.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';
import 'package:ai_fake_news_detector/widgets/media_picker/media_picker_app_bar.dart';
import 'package:ai_fake_news_detector/widgets/media_picker/loading_banner.dart';
import 'package:ai_fake_news_detector/widgets/media_picker/drop_zone.dart';
import 'package:ai_fake_news_detector/widgets/media_picker/pick_row.dart';
import 'package:ai_fake_news_detector/widgets/media_picker/file_info_card.dart';
import 'package:ai_fake_news_detector/widgets/media_picker/error_banner.dart';
import 'package:ai_fake_news_detector/widgets/media_picker/proceed_button.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _accent = Color.fromARGB(255, 17, 101, 235);
const _surface = Color(0xFFF7F6FF);
const _textPrimary = Color(0xFF1A1730);
const _textMuted = Color(0xFF7B78A0);

class MediaPickerPage extends StatefulWidget {
  const MediaPickerPage({super.key});

  @override
  State<MediaPickerPage> createState() => _MediaPickerPageState();
}

class _MediaPickerPageState extends State<MediaPickerPage>
    with SingleTickerProviderStateMixin {
  final MediaPickerService _mediaPickerService = Get.find<MediaPickerService>();

  bool _isLoading = false;
  String? _selectedFilePath;
  String? _fileType;
  int? _fileSize;
  int? _videoDuration;
  String? _errorMessage;
  VideoPlayerController? _videoController;

  // Which pick button is active: 'image' | 'video' | 'any'
  String _activeType = 'image';

  late final AnimationController _btnAnim;

  @override
  void initState() {
    super.initState();
    _btnAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _btnAnim.dispose();
    super.dispose();
  }

  // ── Pickers ─────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    setState(() {
      _activeType = 'image';
      _isLoading = true;
      _errorMessage = null;
      _selectedFilePath = null;
      _fileType = null;
      _fileSize = null;
      _videoDuration = null;
    });
    try {
      final result = await _mediaPickerService.pickImage();
      _handlePickResult(result);
    } catch (e) {
      setState(() => _errorMessage = 'Error picking image: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickVideo() async {
    setState(() {
      _activeType = 'video';
      _isLoading = true;
      _errorMessage = null;
      _selectedFilePath = null;
      _fileType = null;
      _fileSize = null;
      _videoDuration = null;
    });
    await _videoController?.dispose();
    _videoController = null;
    try {
      final result = await _mediaPickerService.pickVideo();
      await _handlePickResult(result);
    } catch (e) {
      setState(() => _errorMessage = 'Error picking video: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMedia() async {
    setState(() {
      _activeType = 'any';
      _isLoading = true;
      _errorMessage = null;
      _selectedFilePath = null;
      _fileType = null;
      _fileSize = null;
      _videoDuration = null;
    });
    await _videoController?.dispose();
    _videoController = null;
    try {
      final result = await _mediaPickerService.pickMedia();
      await _handlePickResult(result);
    } catch (e) {
      setState(() => _errorMessage = 'Error picking media: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePickResult(Map<String, dynamic> result) async {
    if (result['success'] == true) {
      setState(() {
        _selectedFilePath = result['filePath'];
        _fileType = result['fileType'];
        _fileSize = result['fileSize'];
        _videoDuration = result['duration'];
        _errorMessage = null;
      });
      if (_fileType == 'video' && _selectedFilePath != null) {
        _videoController = VideoPlayerController.file(File(_selectedFilePath!));
        await _videoController!.initialize();
        setState(() {});
      }
    } else {
      setState(() => _errorMessage = result['message']);
      if (result['permanentlyDenied'] == true) _showPermissionDeniedDialog();
    }
  }

  void _proceedWithFile() {
    if (_selectedFilePath != null && _fileType != null) {
      MediaAnalysisChannel.startAnalysis(_selectedFilePath!, _fileType!);
      Navigator.pushNamed(context, '/processing');
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: _accent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Permission Required',
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Storage permission has been permanently denied. '
          'Please enable it in app settings to access your gallery.',
          style: GoogleFonts.dmSans(fontSize: 14, color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _mediaPickerService.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Open Settings',
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: const MediaPickerAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading) const LoadingBanner(),
            DropZone(
              selectedFilePath: _selectedFilePath,
              fileType: _fileType,
              videoController: _videoController,
              onTap: _pickMedia,
            ),
            const SizedBox(height: 16),
            if (!_isLoading)
              PickRow(
                activeType: _activeType,
                onPickImage: _pickImage,
                onPickVideo: _pickVideo,
                onPickMedia: _pickMedia,
              ),
            FileInfoCard(
              selectedFilePath: _selectedFilePath,
              fileType: _fileType,
              fileSize: _fileSize,
              videoDuration: _videoDuration,
              mediaPickerService: _mediaPickerService,
            ),
            ErrorBanner(errorMessage: _errorMessage),
            const SizedBox(height: 8),
            if (_selectedFilePath != null && !_isLoading) ...[
              ProceedButton(onPressed: _proceedWithFile),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}