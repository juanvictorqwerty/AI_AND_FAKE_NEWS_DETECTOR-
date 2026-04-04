import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_fake_news_detector/services/media_picker_service.dart';
import 'package:ai_fake_news_detector/services/media_analysis_channel.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _accent = Color.fromARGB(255, 17, 101, 235);
const _accent2 = Color.fromARGB(255, 18, 154, 226);
const _surface = Color(0xFFF7F6FF);
const _surface2 = Color(0xFFFFFFFF);
const _surface3 = Color(0xFFF0EEF9);
const _border = Color(0xFFE4E1F5);
const _border2 = Color(0xFFCCC8EE);
const _textPrimary = Color(0xFF1A1730);
const _textMuted = Color(0xFF7B78A0);
const _errorBg = Color(0xFFFEF2F2);
const _errorBorder = Color(0xFFFECACA);
const _errorText = Color(0xFFDC2626);

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
  late final Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _btnAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _btnScale = Tween<double>(begin: 1, end: 0.96).animate(
        CurvedAnimation(parent: _btnAnim, curve: Curves.easeInOut));
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
        _videoController =
            VideoPlayerController.file(File(_selectedFilePath!));
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
        title: Row(children: [
          const Icon(Icons.lock_outline_rounded, color: _accent, size: 22),
          const SizedBox(width: 8),
          Text('Permission Required',
              style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
        ]),
        content: Text(
          'Storage permission has been permanently denied. '
          'Please enable it in app settings to access your gallery.',
          style: GoogleFonts.dmSans(fontSize: 14, color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textMuted)),
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
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Open Settings',
                style: GoogleFonts.syne(
                    fontSize: 14, fontWeight: FontWeight.w700)),
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
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLoadingBanner(),
            _buildDropZone(),
            const SizedBox(height: 16),
            _buildPickRow(),
            _buildFileInfoCard(),
            _buildErrorBanner(),
            const SizedBox(height: 8),
            if (_selectedFilePath != null && !_isLoading) ...[
              _buildProceedButton(),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface2,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Upload Media',
        style: GoogleFonts.syne(
            fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  Widget _buildLoadingBanner() {
    if (!_isLoading) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: const AlwaysStoppedAnimation<Color>(_accent),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Processing media…',
          style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w500, color: _textMuted),
        ),
      ]),
    );
  }

  // ── Drop zone / preview ───────────────────────────────────────────────────

  Widget _buildDropZone() {
    final hasFile = _selectedFilePath != null;
    return GestureDetector(
      onTap: hasFile ? null : _pickMedia,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: hasFile ? 240 : 180,
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasFile ? _accent : _border2,
            width: hasFile ? 1.5 : 1.5,
            // dashed via custom painter below when empty
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: hasFile ? _buildPreviewContent() : _buildEmptyDrop(),
      ),
    );
  }

  Widget _buildEmptyDrop() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: _surface3, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.upload_rounded, color: _textMuted, size: 26),
        ),
        const SizedBox(height: 14),
        Text('Drop file here or tap to browse',
            style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textPrimary)),
        const SizedBox(height: 6),
        Text('PNG, JPG, MP4, MOV · up to 100 MB',
            style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted)),
      ]),
    );
  }

  Widget _buildPreviewContent() {
    if (_fileType == 'image') {
      return Stack(fit: StackFit.expand, children: [
        Image.file(File(_selectedFilePath!), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: _textMuted, size: 48))),
        // bottom gradient + badge
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC1A1730), Colors.transparent],
              ),
            ),
            child: Row(children: [
              _typeBadge('Image'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFilePath!.split('/').last,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ]),
          ),
        ),
      ]);
    }
    if (_fileType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return Stack(fit: StackFit.expand, alignment: Alignment.center,
            children: [
          AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!)),
          GestureDetector(
            onTap: () => setState(() {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
            }),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.85),
                  shape: BoxShape.circle),
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: _accent,
                size: 28,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC1A1730), Colors.transparent],
                ),
              ),
              child: Row(children: [_typeBadge('Video')]),
            ),
          ),
        ]);
      }
      return const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_accent),
              strokeWidth: 2.5));
    }
    return const SizedBox.shrink();
  }

  Widget _typeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: _accent.withOpacity(.2),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.syne(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF3EEFF),
              letterSpacing: .8)),
    );
  }

  // ── Pick row ──────────────────────────────────────────────────────────────

  Widget _buildPickRow() {
    if (_isLoading) return const SizedBox.shrink();
    return Row(children: [
      Expanded(
          child: _pickButton(
              label: 'Image',
              icon: Icons.image_outlined,
              type: 'image',
              onTap: _pickImage)),
      const SizedBox(width: 10),
      Expanded(
          child: _pickButton(
              label: 'Video',
              icon: Icons.videocam_outlined,
              type: 'video',
              onTap: _pickVideo)),
      const SizedBox(width: 10),
      Expanded(
          child: _pickButton(
              label: 'Any',
              icon: Icons.perm_media_outlined,
              type: 'any',
              onTap: _pickMedia)),
    ]);
  }

  Widget _pickButton({
    required String label,
    required IconData icon,
    required String type,
    required VoidCallback onTap,
  }) {
    final active = _activeType == type;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFAF8FF) : _surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? _accent : _border, width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: active ? _accent : _textMuted),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? _accent : _textMuted)),
        ]),
      ),
    );
  }

  // ── File info card ────────────────────────────────────────────────────────

  Widget _buildFileInfoCard() {
    if (_selectedFilePath == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        if (_fileType != null)
          _infoRow(
              label: 'File type',
              value: _fileType == 'image' ? 'Image' : 'Video'),
        if (_fileSize != null)
          _infoRow(
              label: 'Size',
              value: _mediaPickerService.getFileSizeFormatted(_fileSize!)),
        if (_videoDuration != null)
          _infoRow(
              label: 'Duration',
              value: _mediaPickerService.getDurationFormatted(_videoDuration!),
              isLast: true),
        if (_videoDuration == null && _fileSize != null)
          _infoRow(
              label: 'File path',
              value: _selectedFilePath!.split('/').last,
              isLast: true),
      ]),
    );
  }

  Widget _infoRow(
      {required String label,
      required String value,
      bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: _border, width: 1))),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted)),
            Text(value,
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary)),
          ]),
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _errorBorder),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: _errorText, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_errorMessage!,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: _errorText)),
        ),
      ]),
    );
  }

  // ── Proceed button ────────────────────────────────────────────────────────

  Widget _buildProceedButton() {
    return GestureDetector(
      onTapDown: (_) => _btnAnim.forward(),
      onTapUp: (_) {
        _btnAnim.reverse();
        _proceedWithFile();
      },
      onTapCancel: () => _btnAnim.reverse(),
      child: ScaleTransition(
        scale: _btnScale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_accent, _accent2],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: _accent.withOpacity(.28),
                  blurRadius: 20,
                  offset: const Offset(0, 6))
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'Upload & Analyse',
            style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: .4),
          ),
        ),
      ),
    );
  }
}