import 'package:ai_fake_news_detector/pages/LoginScreen.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  bool _overlayPermissionGranted = false;
  static const platform = MethodChannel('android_intent/android_intent');
  AnimationController? _animController;
  Animation<double>? _fadeAnim;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController!, curve: Curves.easeOut);
    _animController!.forward();

    // Listen for app lifecycle to check permission when returning from settings
    _lifecycleListener = AppLifecycleListener(
      onResume: () => _checkOverlayPermission(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverlayPermission();
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _animController?.dispose();
    super.dispose();
  }

  Future<void> _checkOverlayPermission() async {
    try {
      final bool result = await platform.invokeMethod('canDrawOverlays');
      if (mounted) {
        setState(() => _overlayPermissionGranted = result);
      }
    } catch (e) {
      debugPrint("Error checking permission: $e");
      if (mounted) setState(() => _overlayPermissionGranted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim ?? const AlwaysStoppedAnimation(1.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel("Account"),
              const SizedBox(height: 10),
              _buildCard([
                _buildTile(
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFE53935),
                  iconBg: const Color(0xFFFFEBEE),
                  title: "Log out",
                  subtitle: "Sign out of your account",
                  onTap: () => _showLogoutDialog(context),
                ),
              ]),
              const SizedBox(height: 28),
              _sectionLabel("Permissions"),
              const SizedBox(height: 10),
              _buildCard([
                _buildOverlayTile(context),
              ]),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  "AFND v1.0.0",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: const Text(
        "Settings",
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
          letterSpacing: -0.5,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFEEEEF2), height: 1),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9E9EB8),
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map((e) => Column(children: [
                  e.value,
                  if (e.key < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 58,
                      endIndent: 16,
                      color: Colors.grey[100],
                    ),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey[350], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayTile(BuildContext context) {
    return _buildTile(
      icon: Icons.picture_in_picture_alt_rounded,
      iconColor: GlobalColors.mainColor,
      iconBg: GlobalColors.mainColor.withOpacity(0.1),
      title: "Display over other apps",
      subtitle: "Required for overlay scanning feature",
      onTap: () => _openOverlayPermissionSettings(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _overlayPermissionGranted
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _overlayPermissionGranted ? "Enabled" : "Disabled",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _overlayPermissionGranted
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[350], size: 22),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Color(0xFFE53935), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                "Log out?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You'll need to sign in again to access your account.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text("Cancel",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final authController = Get.find<AuthController>();
                        await authController.signOut();
                        Get.offAll(() => Login());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Log out",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the MANAGE_OVERLAY_PERMISSION settings screen directly —
  /// the exact page where users toggle "Allow display over other apps".
  void _openOverlayPermissionSettings(BuildContext context) async {
    try {
      // First try: dedicated method that fires the overlay-specific intent
      await platform.invokeMethod('openOverlaySettings');

      // Re-check permission when the user returns
      await Future.delayed(const Duration(milliseconds: 800));
      await _checkOverlayPermission();
    } catch (e) {
      debugPrint("Primary overlay intent failed: $e — trying fallback");
      try {
        // Fallback: pass the action + package URI via the generic launch method
        final Map<String, dynamic> args = {
          'action': 'android.settings.action.MANAGE_OVERLAY_PERMISSION',
          'data': 'package:com.example.ai_fake_news_detector',
        };
        await platform.invokeMethod('launch', args);

        await Future.delayed(const Duration(milliseconds: 800));
        await _checkOverlayPermission();
      } catch (e2) {
        debugPrint("Fallback also failed: $e2");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF1A1A2E),
              content: const Text(
                "Go to Settings → Apps → AFND → Display over other apps",
                style: TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: "OK",
                textColor: GlobalColors.mainColor,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    }
  }
}