import 'package:flutter/material.dart';

class SettingsSectionLabel extends StatelessWidget {
  final String label;

  const SettingsSectionLabel({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9E9EB8),
        letterSpacing: 1.4,
      ),
    );
  }
}
