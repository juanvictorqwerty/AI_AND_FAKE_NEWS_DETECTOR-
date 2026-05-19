import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:ai_fake_news_detector/widgets/home_page/home_app_bar.dart';
import 'package:ai_fake_news_detector/widgets/home_page/home_header.dart';
import 'package:ai_fake_news_detector/widgets/home_page/feature_cards.dart';

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
      appBar: HomeAppBar(isDark: isDark, scaleController: _scaleController),
      body: FadeTransition(
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
                  HomeHeader(isDark: isDark),
                  const SizedBox(height: 40),
                  FeatureCards(
                    isDark: isDark,
                    buttonControllers: _buttonControllers,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
