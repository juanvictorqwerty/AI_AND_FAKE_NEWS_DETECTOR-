import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';

import 'package:ai_fake_news_detector/widgets/guide_page/hero_section.dart';
import 'package:ai_fake_news_detector/widgets/guide_page/quick_start_flow.dart';
import 'package:ai_fake_news_detector/widgets/guide_page/background_processing_info.dart';
import 'package:ai_fake_news_detector/widgets/guide_page/direct_app_usage.dart';
import 'package:ai_fake_news_detector/widgets/guide_page/features_list.dart';
import 'package:ai_fake_news_detector/widgets/guide_page/understanding_results.dart';
import 'package:ai_fake_news_detector/widgets/guide_page/tips_section.dart';
import 'package:ai_fake_news_detector/widgets/guide_page/faq_section.dart';
import 'package:ai_fake_news_detector/widgets/guide_page/call_to_action.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: GlobalColors.mainColor,
        elevation: 0,
        title: const Text(
          "How to Use",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            HeroSection(),
            QuickStartFlow(),
            BackgroundProcessingInfo(),
            DirectAppUsage(),
            FeaturesList(),
            UnderstandingResults(),
            TipsSection(),
            FAQSection(),
            CallToAction(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
