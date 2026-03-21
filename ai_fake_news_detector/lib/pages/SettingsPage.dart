import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/settings/dialogs/change_password_dialog.dart';
import 'package:ai_fake_news_detector/widgets/settings/dialogs/complete_profile_dialog.dart';
import 'package:ai_fake_news_detector/widgets/settings/dialogs/edit_profile_dialog.dart';
import 'package:ai_fake_news_detector/widgets/settings/dialogs/logout_dialog.dart';
import 'package:ai_fake_news_detector/widgets/settings/overlay_permission_tile.dart';
import 'package:ai_fake_news_detector/widgets/settings/settings_card.dart';
import 'package:ai_fake_news_detector/widgets/settings/settings_section_label.dart';
import 'package:ai_fake_news_detector/widgets/settings/settings_tile.dart';
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

  void _showCompleteProfileDialog() {
    CompleteProfileDialog.show(context, () => setState(() {}));
  }

  void _showEditProfileDialog() {
    EditProfileDialog.show(context, () => setState(() {}));
  }

  void _showChangePasswordDialog() {
    ChangePasswordDialog.show(context);
  }

  void _showLogoutDialog() {
    LogoutDialog.show(context);
  }

  /// Opens the MANAGE_OVERLAY_PERMISSION settings screen directly —
  /// the exact page where users toggle "Allow display over other apps".
  Future<void> _openOverlayPermissionSettings() async {
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
        if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim ?? const AlwaysStoppedAnimation(1.0),
        child: Obx(() {
          // These values will update automatically when authController changes
          final bool isAnonymous = authController.isAnonymousUser;
          final String userName = authController.userName;
          final String userEmail = authController.userEmail;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsSectionLabel(label: "Account"),
                const SizedBox(height: 10),
                SettingsCard(
                  children: [
                    // Profile info tile
                    SettingsTile(
                      icon: Icons.person_outline_rounded,
                      iconColor: GlobalColors.mainColor,
                      iconBg: GlobalColors.mainColor.withOpacity(0.1),
                      title: userName,
                      subtitle: isAnonymous ? "Anonymous user" : userEmail.isNotEmpty ? userEmail : "No email",
                      onTap: () {},
                    ),
                    // Complete/Edit profile tile
                    SettingsTile(
                      icon: isAnonymous ? Icons.person_add_alt_1_rounded : Icons.edit_outlined,
                      iconColor: const Color(0xFF2196F3),
                      iconBg: const Color(0xFFE3F2FD),
                      title: isAnonymous ? "Complete profile" : "Edit profile",
                      subtitle: isAnonymous
                        ? "Add name, email & password"
                        : "Update your personal info",
                      onTap: () => isAnonymous 
                        ? _showCompleteProfileDialog()
                        : _showEditProfileDialog(),
                    ),
                    // Password tile - only for non-anonymous users
                    if (!isAnonymous)
                      SettingsTile(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFF9C27B0),
                        iconBg: const Color(0xFFF3E5F5),
                        title: "Change password",
                        subtitle: "Update your account password",
                        onTap: _showChangePasswordDialog,
                      ),
                    SettingsTile(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFE53935),
                      iconBg: const Color(0xFFFFEBEE),
                      title: "Log out",
                      subtitle: "Sign out of your account",
                      onTap: _showLogoutDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const SettingsSectionLabel(label: "Permissions"),
                const SizedBox(height: 10),
                SettingsCard(
                  children: [
                    OverlayPermissionTile(
                      isGranted: _overlayPermissionGranted,
                      onOpenSettings: _openOverlayPermissionSettings,
                      platform: platform,
                    ),
                  ],
                ),
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
          );
        }),
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
}
