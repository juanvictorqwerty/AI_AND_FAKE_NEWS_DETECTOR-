import 'dart:async';

import 'package:ai_fake_news_detector/pages/HomePage.dart';
import 'package:ai_fake_news_detector/pages/LoginScreen.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:get/get.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:flutter/material.dart';

class SplashView extends StatefulWidget {
  const SplashView({Key? key}): super(key: key);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Wait for 2 seconds
    await Future.delayed(Duration(seconds: 2));
    
    // Check if user is logged in
    final authController = Get.find<AuthController>();
    
    // Wait for auth controller to initialize
    while (!authController.isInitialized.value) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    if (authController.isLoggedIn) {
      // Navigate to HomePage if logged in
      Get.offAll(() => Homepage());
    } else {
      // Navigate to Login if not logged in
      Get.offAll(() => Login());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlobalColors.mainColor,
      body: const Center(
        child: Text(
          'AIFND',
        style: TextStyle(
          color: Colors.white,
          fontSize: 37,
          fontWeight: FontWeight.bold,
        ),
        ),
      ),
    );
  }
}
