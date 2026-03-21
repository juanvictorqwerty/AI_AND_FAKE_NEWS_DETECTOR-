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
    final authController = Get.find<AuthController>();
    final bool isAnonymous = authController.isAnonymous;
    final String userName = authController.userName;
    final String userEmail = authController.userEmail;

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
                // Profile info tile
                _buildTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: GlobalColors.mainColor,
                  iconBg: GlobalColors.mainColor.withOpacity(0.1),
                  title: userName,
                  subtitle: isAnonymous ? "Anonymous user" : userEmail.isNotEmpty ? userEmail : "No email",
                  onTap: () {},
                ),
                // Complete/Edit profile tile
                _buildTile(
                  icon: isAnonymous ? Icons.person_add_alt_1_rounded : Icons.edit_outlined,
                  iconColor: const Color(0xFF2196F3),
                  iconBg: const Color(0xFFE3F2FD),
                  title: isAnonymous ? "Complete profile" : "Edit profile",
                  subtitle: isAnonymous 
                    ? "Add name, email & password"
                    : "Update your personal info",
                  onTap: () => isAnonymous 
                    ? _showCompleteProfileDialog(context)
                    : _showEditProfileDialog(context),
                ),
                // Password tile - only for non-anonymous users
                if (!isAnonymous)
                  _buildTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFF9C27B0),
                    iconBg: const Color(0xFFF3E5F5),
                    title: "Change password",
                    subtitle: "Update your account password",
                    onTap: () => _showChangePasswordDialog(context),
                  ),
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

  /// Shows dialog for anonymous users to complete their profile
  void _showCompleteProfileDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final authController = Get.find<AuthController>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: Color(0xFF2196F3), size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Complete Your Profile",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create an account to save your data",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: nameController,
                    label: "Name",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: emailController,
                    label: "Email",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: passwordController,
                    label: "Password",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: confirmPasswordController,
                    label: "Confirm Password",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
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
                          onPressed: isLoading
                              ? null
                              : () async {
                                  // Validate inputs
                                  if (nameController.text.isEmpty ||
                                      emailController.text.isEmpty ||
                                      passwordController.text.isEmpty) {
                                    Get.snackbar('Error', 'Please fill in all fields');
                                    return;
                                  }
                                  if (passwordController.text !=
                                      confirmPasswordController.text) {
                                    Get.snackbar('Error', 'Passwords do not match');
                                    return;
                                  }
                                  if (passwordController.text.length < 6) {
                                    Get.snackbar('Error',
                                        'Password must be at least 6 characters');
                                    return;
                                  }

                                  setState(() => isLoading = true);

                                  final success =
                                      await authController.upgradeAnonymousUser(
                                    name: nameController.text.trim(),
                                    email: emailController.text.trim(),
                                    password: passwordController.text,
                                  );

                                  setState(() => isLoading = false);

                                  if (success && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Create Account",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows dialog for registered users to edit their profile
  void _showEditProfileDialog(BuildContext context) {
    final authController = Get.find<AuthController>();
    final nameController = TextEditingController(text: authController.userName);
    final emailController = TextEditingController(text: authController.userEmail);
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Color(0xFF2196F3), size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Edit Profile",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Update your personal information",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: nameController,
                    label: "Name",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: emailController,
                    label: "Email",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
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
                          onPressed: isLoading
                              ? null
                              : () async {
                                  // Validate inputs
                                  if (nameController.text.isEmpty ||
                                      emailController.text.isEmpty) {
                                    Get.snackbar('Error', 'Please fill in all fields');
                                    return;
                                  }

                                  setState(() => isLoading = true);

                                  final success = await authController.updateProfile(
                                    name: nameController.text.trim(),
                                    email: emailController.text.trim(),
                                  );

                                  setState(() => isLoading = false);

                                  if (success && context.mounted) {
                                    Navigator.pop(context);
                                    // Refresh UI
                                    this.setState(() {});
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Save Changes",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows dialog for changing password (for registered users)
  void _showChangePasswordDialog(BuildContext context) {
    final authController = Get.find<AuthController>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline_rounded,
                        color: Color(0xFF9C27B0), size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Change Password",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your current and new password",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: currentPasswordController,
                    label: "Current Password",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: newPasswordController,
                    label: "New Password",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: confirmPasswordController,
                    label: "Confirm New Password",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
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
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (currentPasswordController.text.isEmpty ||
                                      newPasswordController.text.isEmpty ||
                                      confirmPasswordController.text.isEmpty) {
                                    Get.snackbar("Error", "Please fill in all fields");
                                    return;
                                  }
                                  if (newPasswordController.text !=
                                      confirmPasswordController.text) {
                                    Get.snackbar("Error", "New passwords do not match");
                                    return;
                                  }
                                  if (newPasswordController.text.length < 6) {
                                    Get.snackbar("Error",
                                        "Password must be at least 6 characters");
                                    return;
                                  }
                                  setState(() => isLoading = true);
                                  final success = await authController.changePassword(
                                    currentPassword: currentPasswordController.text,
                                    newPassword: newPasswordController.text,
                                  );
                                  setState(() => isLoading = false);
                                  if (success && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C27B0),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Change Password",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper widget for text fields in dialogs
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: GlobalColors.mainColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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