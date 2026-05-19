import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:ai_fake_news_detector/pages/FactCheckPage.dart';
import 'package:ai_fake_news_detector/pages/MediaPickerPage.dart';
import 'package:ai_fake_news_detector/pages/GuidePage.dart';

class FeatureCards extends StatelessWidget {
  final bool isDark;
  final List<AnimationController> buttonControllers;

  const FeatureCards({
    super.key,
    required this.isDark,
    required this.buttonControllers,
  });

  @override
  Widget build(BuildContext context) {
    final features = [
      {
        'title': 'Fact Check',
        'icon': Icons.verified_user,
        'color': const Color(0xFF10B981),
        'page': const FactCheckPage(),
        'description': 'Verify facts instantly',
      },
      {
        'title': 'Upload Media',
        'icon': Icons.cloud_upload_outlined,
        'color': const Color(0xFF8B5CF6),
        'page': const MediaPickerPage(),
        'description': 'Analyze images & videos',
      },
      {
        'title': 'Guide',
        'icon': Icons.lightbulb_outlined,
        'color': const Color(0xFFF97316),
        'page': const GuidePage(),
        'description': 'Learn how to detect',
      },
    ];

    return Column(
      children: List.generate(
        features.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: buttonControllers[index],
                curve: Curves.easeOut,
              ),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: buttonControllers[index],
                  curve: Curves.easeOut,
                ),
              ),
              child: _FeatureCard(
                feature: features[index],
                isDark: isDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final Map<String, dynamic> feature;
  final bool isDark;

  const _FeatureCard({
    required this.feature,
    required this.isDark,
  });

  void _onCardHover(bool isHovering) {
    // Implement haptic feedback or additional animations here
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => feature['page'] as Widget),
        );
      },
      child: MouseRegion(
        onEnter: (_) => _onCardHover(true),
        onExit: (_) => _onCardHover(false),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      (feature['color'] as Color).withOpacity(0.15),
                      (feature['color'] as Color).withOpacity(0.05),
                    ]
                  : [
                      (feature['color'] as Color).withOpacity(0.08),
                      (feature['color'] as Color).withOpacity(0.02),
                    ],
            ),
            border: Border.all(
              color: (feature['color'] as Color).withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (feature['color'] as Color).withOpacity(0.2),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        feature['icon'] as IconData,
                        color: feature['color'] as Color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature['title'] as String,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F1419),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            feature['description'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: feature['color'] as Color,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
