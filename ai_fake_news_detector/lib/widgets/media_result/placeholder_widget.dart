import 'package:flutter/material.dart';

/// A reusable placeholder widget for displaying an icon and text.
class PlaceholderWidget extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final double height;

  const PlaceholderWidget({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color ?? Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              text,
              style: TextStyle(fontSize: 16, color: color ?? Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
