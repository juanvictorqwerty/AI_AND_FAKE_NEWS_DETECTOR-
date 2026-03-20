import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:flutter/material.dart';

class SplashView extends StatelessWidget{
  const SplashView({Key? key}):super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      backgroundColor: GlobalColors.mainColor,
      body: const Center(
        child: Text(
          'Logo',
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