import 'dart:async';

import 'package:ai_fake_news_detector/pages/LoginScreen.dart';
import 'package:get/get.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:flutter/material.dart';

class SplashView extends StatelessWidget{
  const SplashView({Key? key}):super(key: key);

  @override
  Widget build(BuildContext context) {
    Timer(Duration(seconds: 2),() {
        Get.to(Login());
      }
      );
    // TODO: implement build
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