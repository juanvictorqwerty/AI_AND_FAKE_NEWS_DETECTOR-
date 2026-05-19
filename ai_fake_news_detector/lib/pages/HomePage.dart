import 'package:ai_fake_news_detector/pages/FactCheckPage.dart';
import 'package:ai_fake_news_detector/pages/MediaPickerPage.dart';
import 'package:ai_fake_news_detector/pages/SettingsPage.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/pages/GuidePage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:get/get.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late List<AnimationController> _buttonControllers;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _prolongToken();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _buttonControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      for (int i = 0; i < _buttonControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 150), () {
          if (mounted) {
            _buttonControllers[i].forward();
          }
        });
      }
    });
  }

  Future<void> _prolongToken() async {
    final authController = Get.find<AuthController>();
    final extended = await authController.prolongTokenIfNeeded();
    if (extended) {
      debugPrint('Token prolonged for 7 days');
    } else {
      debugPrint('Token already prolonged today or not logged in');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    for (var controller in _buttonControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1419)
          : const Color(0xFFFAFAFA),
      appBar: _buildModernAppBar(isDark),
      body: _buildBody(context, isDark),
    );
  }

  PreferredSizeWidget _buildModernAppBar(bool isDark) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Detector",
            style: TextStyle(
              color: GlobalColors.mainColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            "AI & Fake News",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
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
            CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
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

  Widget _buildBody(BuildContext context, bool isDark) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController),
      child: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 40),
                _buildFeatureCards(isDark),
                const SizedBox(height: 32),
                _buildQuickStats(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
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

  Widget _buildFeatureCards(bool isDark) {
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
                parent: _buttonControllers[index],
                curve: Curves.easeOut,
              ),
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.3, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _buttonControllers[index],
                      curve: Curves.easeOut,
                    ),
                  ),
              child: _buildFeatureCard(
                features[index] as Map<String, dynamic>,
                isDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature, bool isDark) {
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
                      feature['color'].withOpacity(0.15),
                      feature['color'].withOpacity(0.05),
                    ]
                  : [
                      feature['color'].withOpacity(0.08),
                      feature['color'].withOpacity(0.02),
                    ],
            ),
            border: Border.all(
              color: feature['color'].withOpacity(0.2),
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
                        color: feature['color'].withOpacity(0.2),
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F1419),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            feature['description'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
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

  Widget _buildQuickStats(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Stats",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F1419),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              title: 'Verified',
              value: '127',
              icon: Icons.check_circle,
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'Detected',
              value: '42',
              icon: Icons.warning_rounded,
              color: const Color(0xFFEF4444),
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Colors.grey[900] : Colors.grey[50],
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F1419),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onCardHover(bool isHovering) {
    // Implement haptic feedback or additional animations here
  }
}
