import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';

class QuickStartFlow extends StatelessWidget {
  const QuickStartFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(
                "Quick Start (Primary Flow)",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStep(
                  context,
                  icon: Icons.forum_outlined,
                  title: "1. Open Any App",
                  desc:
                      "Find suspicious content in WhatsApp,Facebook, or Browser.",
                ),
                _buildDivider(),
                _buildStep(
                  context,
                  icon: Icons.share_rounded,
                  title: "2. Tap Share",
                  desc: "Select 'Share' on the message, image, or link.",
                ),
                _buildDivider(),
                _buildStep(
                  context,
                  icon: Icons.touch_app_rounded,
                  title: "3. Select This App",
                  desc: "Choose the AI Detector app from the share menu.",
                  isPrimary: true,
                ),
                _buildDivider(),
                _buildStep(
                  context,
                  icon: Icons.phone_android_rounded,
                  title: "4. Keep Using Phone",
                  desc: "No waiting! The app processes in the background.",
                ),
                _buildDivider(),
                _buildStep(
                  context,
                  icon: Icons.notifications_active_rounded,
                  title: "5. Get Notification",
                  desc: "Receive a quick alert with the verification results.",
                  isSuccess: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    bool isPrimary = false,
    bool isSuccess = false,
  }) {
    Color iconColor = GlobalColors.mainColor;
    if (isSuccess) iconColor = Colors.green;
    if (isPrimary) iconColor = Colors.purple;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, top: 8.0, bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(width: 2, height: 20, color: Colors.grey[300]),
      ),
    );
  }
}
