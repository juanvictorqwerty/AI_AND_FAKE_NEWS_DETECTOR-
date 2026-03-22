import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ai_fake_news_detector/widgets/quick_settings_overlay.dart';

/// Overlay Page for Quick Settings Tile
/// This page is displayed when the Quick Settings tile is clicked
class OverlayPage extends StatefulWidget {
  const OverlayPage({Key? key}) : super(key: key);

  @override
  State<OverlayPage> createState() => _OverlayPageState();
}

class _OverlayPageState extends State<OverlayPage> {
  static const platform =
      MethodChannel('com.example.ai_fake_news_detector/overlay');

  String? _triggerSource;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTriggerSource();
  }

  Future<void> _loadTriggerSource() async {
    try {
      final source = await platform.invokeMethod('getTriggerSource');
      setState(() {
        _triggerSource = source as String?;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      debugPrint('Error getting trigger source: ${e.message}');
      setState(() {
        _triggerSource = 'Unknown';
        _isLoading = false;
      });
    }
  }

  Future<void> _closeOverlay() async {
    try {
      await platform.invokeMethod('closeOverlay');
    } on PlatformException catch (e) {
      debugPrint('Error closing overlay: ${e.message}');
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: QuickSettingsOverlay(
        triggerSource: _triggerSource,
        message: 'Fact-check triggered from Quick Settings!',
      ),
    );
  }
}
