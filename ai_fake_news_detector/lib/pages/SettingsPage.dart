import 'package:ai_fake_news_detector/pages/LoginScreen.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _overlayPermissionGranted = false;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkOverlayPermission();
  }

  Future<void> _checkOverlayPermission() async {
    try {
      final status = await Permission.systemAlertWindow.status;
      if (mounted) {
        setState(() {
          _overlayPermissionGranted = status.isGranted;
          _isCheckingPermission = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _overlayPermissionGranted = false;
          _isCheckingPermission = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlobalColors.mainColor,
        title: Text(
          "Settings",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Menu",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: GlobalColors.textColor,
                  ),
                ),
                const SizedBox(height: 15),
                
                // Log out menu item with bin icon
                _buildMenuItem(
                  icon: Icons.delete_outline,
                  title: "Log out",
                  onTap: () => _showLogoutDialog(context),
                ),
                
                Divider(height: 1, color: Colors.grey[300]),
                
                // Permission to display over other apps - Toggle switch
                _buildToggleMenuItem(
                  icon: Icons.picture_in_picture,
                  title: "Permission to display over other apps",
                  value: _overlayPermissionGranted,
                  isLoading: _isCheckingPermission,
                  onChanged: (bool value) {
                    if (value) {
                      _requestOverlayPermission();
                    } else {
                      _showCannotDisableDialog();
                    }
                  },
                ),
              ],
            ),
          )  
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.red[700]),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: GlobalColors.textColor,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildToggleMenuItem({
    required IconData icon,
    required String title,
    required bool value,
    required bool isLoading,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: GlobalColors.mainColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: GlobalColors.textColor,
        ),
      ),
      trailing: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: GlobalColors.mainColor,
            ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Log out"),
        content: Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authController = Get.find<AuthController>();
              await authController.signOut();
              // Navigate to login screen after logout
              Get.offAll(() => Login());
            },
            child: Text(
              "Log out",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _requestOverlayPermission() async {
    // SYSTEM_ALERT_WINDOW is a special permission that cannot be requested
    // programmatically in most Android versions. We need to guide the user
    // to enable it in system settings.
    
    // First check if already granted
    final status = await Permission.systemAlertWindow.status;
    
    if (status.isGranted) {
      setState(() {
        _overlayPermissionGranted = true;
      });
      Get.snackbar(
        "Permission Granted",
        "Display over other apps permission is already granted",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Show dialog explaining how to enable the permission
    if (mounted) {
      _showOverlayPermissionDialog();
    }
  }

  void _showOverlayPermissionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Enable Display Over Other Apps"),
        content: Text(
          "To enable this feature, you need to:\n\n"
          "1. Tap 'Open Settings'\n"
          "2. Find 'Display over other apps'\n"
          "3. Enable it for AI & FAKE NEWS DETECTOR\n\n"
          "Note: This permission allows the app to display notifications over other apps.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Open app settings where user can enable the permission
              _openOverlaySettings();
            },
            child: Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  void _openOverlaySettings() async {
    try {
      // Try to open the specific overlay settings
      const _ = MethodChannel('android_intent/android_intent');
      
      // Open app details settings where overlay permission can be enabled
      await const MethodChannel('flutter/platform').invokeMethod('openAppSettings');
      
      // After user returns, check the permission status
      await Future.delayed(const Duration(seconds: 2));
      await _checkOverlayPermission();
      
    } catch (e) {
      // Fallback: try to open general app settings
      try {
        await openAppSettings();
        await Future.delayed(const Duration(seconds: 2));
        await _checkOverlayPermission();
      } catch (e2) {
        Get.snackbar(
          "Error",
          "Could not open settings. Please enable manually in system settings.",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  void _showCannotDisableDialog() {
    Get.snackbar(
      "Cannot Disable",
      "This permission can only be disabled in system settings",
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
