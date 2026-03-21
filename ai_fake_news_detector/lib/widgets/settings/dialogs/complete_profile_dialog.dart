import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/widgets/settings/dialogs/dialog_text_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CompleteProfileDialog extends StatefulWidget {
  final VoidCallback onProfileCompleted;

  const CompleteProfileDialog({
    super.key,
    required this.onProfileCompleted,
  });

  static void show(BuildContext context, VoidCallback onProfileCompleted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompleteProfileDialog(
        onProfileCompleted: onProfileCompleted,
      ),
    );
  }

  @override
  State<CompleteProfileDialog> createState() => _CompleteProfileDialogState();
}

class _CompleteProfileDialogState extends State<CompleteProfileDialog> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final authController = Get.find<AuthController>();
  bool isLoading = false;

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
              DialogTextField(
                controller: nameController,
                label: "Name",
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: emailController,
                label: "Email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DialogTextField(
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
                                  await authController.completeProfile(
                                name: nameController.text.trim(),
                                email: emailController.text.trim(),
                                password: passwordController.text,
                              );

                              setState(() => isLoading = false);

                              if (success && mounted) {
                                Navigator.pop(context);
                                widget.onProfileCompleted();
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
    );
  }
}
