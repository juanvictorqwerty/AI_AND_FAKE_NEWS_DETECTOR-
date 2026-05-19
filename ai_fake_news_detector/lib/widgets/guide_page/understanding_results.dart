import 'package:flutter/material.dart';

class UnderstandingResults extends StatelessWidget {
  const UnderstandingResults({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 Understanding Results",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildResultItem(Icons.speed_rounded, "Confidence Score", "A percentage showing how certain the AI is about its conclusion.", Colors.blueGrey),
                const SizedBox(height: 12),
                _buildResultItem(Icons.link_rounded, "Sources", "Links to trusted articles or fact-checks validating the claim.", Colors.blue),
                const SizedBox(height: 12),
                _buildResultItem(Icons.warning_amber_rounded, "Warnings", "Red flags indicating highly suspicious or dangerous misinformation.", Colors.orange),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildResultItem(IconData icon, String title, String desc, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(desc, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
