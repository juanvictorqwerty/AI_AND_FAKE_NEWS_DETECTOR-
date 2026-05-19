import 'package:flutter/material.dart';

class FAQSection extends StatelessWidget {
  const FAQSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "❓ FAQ",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFAQItem(
            "How long does verification take?",
            "Usually a few seconds. You'll get a notification as soon as it's done!",
          ),
          _buildFAQItem(
            "Can it detect all fake news?",
            "While highly accurate, it's not perfect. It's a tool to assist you, but critical thinking is always required.",
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Builder(
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              question,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  answer,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
