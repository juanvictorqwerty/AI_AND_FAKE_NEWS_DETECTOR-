import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';

class DirectAppUsage extends StatelessWidget {
  const DirectAppUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📲 Direct App Usage",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCard(Icons.open_in_new_rounded, "Open App", "Launch the app from your home screen."),
              const SizedBox(width: 12),
              _buildCard(Icons.upload_file_rounded, "Upload", "Paste text or upload an image directly."),
              const SizedBox(width: 12),
              _buildCard(Icons.analytics_rounded, "View", "Get deep insights and sources instantly."),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(IconData icon, String title, String desc) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: GlobalColors.mainColor, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center,),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center, maxLines: 3,),
          ],
        ),
      ),
    );
  }
}
