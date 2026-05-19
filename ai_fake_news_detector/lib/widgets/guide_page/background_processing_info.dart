import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';

class BackgroundProcessingInfo extends StatelessWidget {
  const BackgroundProcessingInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, GlobalColors.mainColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: GlobalColors.mainColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text(
            "Background Processing",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "When you share content to the app, it runs silently in the background. You don't have to wait or keep the app open. Results will pop up as a notification!",
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
