import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/widgets/settings/dialogs/dialog_text_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final authController = Get.find<AuthController>();
  bool isLoading = false;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              DialogTextField(
                controller: currentPasswordController,
                label: "Current Password",
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: newPasswordController,
                label: "New Password",
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DialogTextField(
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
                              if (success && mounted) {
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
    );
  }
}
