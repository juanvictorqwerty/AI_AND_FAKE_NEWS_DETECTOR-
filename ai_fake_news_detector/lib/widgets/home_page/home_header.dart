import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final bool isDark;

  const HomeHeader({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome Back",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F1419),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Verify the truth behind AI and fake news",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
