import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OverlayPermissionTile extends StatelessWidget {
  final bool isGranted;
  final VoidCallback onOpenSettings;
  final MethodChannel platform;

  const OverlayPermissionTile({
    super.key,
    required this.isGranted,
    required this.onOpenSettings,
    required this.platform,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.picture_in_picture_alt_rounded,
      iconColor: GlobalColors.mainColor,
      iconBg: GlobalColors.mainColor.withOpacity(0.1),
      title: "Display over other apps",
      subtitle: "Required for overlay scanning feature",
      onTap: onOpenSettings,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isGranted ? "Enabled" : "Disabled",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isGranted
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[350], size: 22),
        ],
      ),
    );
  }
}
