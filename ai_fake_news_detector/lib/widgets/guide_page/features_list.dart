import 'package:flutter/material.dart';

class FeaturesList extends StatelessWidget {
  const FeaturesList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🧩 Core Features",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFeatureTile(
            icon: Icons.text_snippet_rounded,
            title: "News Verification",
            desc:
                "Checks text against trusted sources and fact-checking databases.",
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.image_search_rounded,
            title: "Image Verification",
            desc:
                "Analyzes images for manipulation, deepfakes, or misleading context.",
            color: Colors.pink,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            desc,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
      ),
    );
  }
}
