import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/pages/SettingsPage.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  final AnimationController scaleController;

  const HomeAppBar({
    super.key,
    required this.isDark,
    required this.scaleController,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AFND",
            style: TextStyle(
              color: GlobalColors.mainColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: scaleController, curve: Curves.elasticOut),
          ),
          child: IconButton(
            icon: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.history,
                color: GlobalColors.mainColor,
                size: 20,
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
        ),
        ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: scaleController, curve: Curves.elasticOut),
          ),
          child: IconButton(
            icon: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.settings,
                color: GlobalColors.mainColor,
                size: 20,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
