import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:flutter/material.dart';

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
            _HeroSection(),
            _QuickStartFlow(),
            _BackgroundProcessingInfo(),
            _DirectAppUsage(),
            _FeaturesList(),
            _UnderstandingResults(),
            _TipsSection(),
            _FAQSection(),
            _CallToAction(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      decoration: const BoxDecoration(
        color: GlobalColors.mainColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user_rounded, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            "How to Use the App",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Verify information anytime, anywhere.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuickStartFlow extends StatelessWidget {
  const _QuickStartFlow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(
                "Quick Start (Primary Flow)",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                _buildStep(
                  context,
                  icon: Icons.forum_outlined,
                  title: "1. Open Any App",
                  desc: "Find suspicious content in WhatsApp, Twitter, or Browser.",
                ),
                _buildDivider(),
                _buildStep(
                  context,
                  icon: Icons.share_rounded,
                  title: "2. Tap Share",
                  desc: "Select 'Share' on the message, image, or link.",
                ),
                _buildDivider(),
                _buildStep(
                  context,
                  icon: Icons.touch_app_rounded,
                  title: "3. Select This App",
                  desc: "Choose the AI Detector app from the share menu.",
                  isPrimary: true,
                ),
                _buildDivider(),
                _buildStep(
                  context,
                  icon: Icons.phone_android_rounded,
                  title: "4. Keep Using Phone",
                  desc: "No waiting! The app processes in the background.",
                ),
                _buildDivider(),
                _buildStep(
                  context,
                  icon: Icons.notifications_active_rounded,
                  title: "5. Get Notification",
                  desc: "Receive a quick alert with the verification results.",
                  isSuccess: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, {required IconData icon, required String title, required String desc, bool isPrimary = false, bool isSuccess = false}) {
    Color iconColor = GlobalColors.mainColor;
    if (isSuccess) iconColor = Colors.green;
    if (isPrimary) iconColor = Colors.purple;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, top: 8.0, bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 2,
          height: 20,
          color: Colors.grey[300],
        ),
      ),
    );
  }
}

class _BackgroundProcessingInfo extends StatelessWidget {
  const _BackgroundProcessingInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, GlobalColors.mainColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: GlobalColors.mainColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text(
            "Background Processing",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "When you share content to the app, it runs silently in the background. You don't have to wait or keep the app open. Results will pop up as a notification!",
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DirectAppUsage extends StatelessWidget {
  const _DirectAppUsage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📲 Direct App Usage",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCard(Icons.open_in_new_rounded, "Open App", "Launch the app from your home screen."),
              const SizedBox(width: 12),
              _buildCard(Icons.upload_file_rounded, "Upload", "Paste text or upload an image directly."),
              const SizedBox(width: 12),
              _buildCard(Icons.analytics_rounded, "View", "Get deep insights and sources instantly."),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(IconData icon, String title, String desc) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: GlobalColors.mainColor, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center,),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center, maxLines: 3,),
          ],
        ),
      ),
    );
  }
}

class _FeaturesList extends StatelessWidget {
  const _FeaturesList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🧩 Core Features",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFeatureTile(
            icon: Icons.text_snippet_rounded,
            title: "Text Verification",
            desc: "Checks text against trusted sources and fact-checking databases.",
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.image_search_rounded,
            title: "Image Verification",
            desc: "Analyzes images for manipulation, deepfakes, or misleading context.",
            color: Colors.pink,
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.smart_toy_rounded,
            title: "AI Content Detection",
            desc: "Detects if text or images were generated by AI models like ChatGPT or Midjourney.",
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({required IconData icon, required String title, required String desc, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ),
      ),
    );
  }
}

class _UnderstandingResults extends StatelessWidget {
  const _UnderstandingResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 Understanding Results",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildResultItem(Icons.speed_rounded, "Confidence Score", "A percentage showing how certain the AI is about its conclusion.", Colors.blueGrey),
                const SizedBox(height: 12),
                _buildResultItem(Icons.link_rounded, "Sources", "Links to trusted articles or fact-checks validating the claim.", Colors.blue),
                const SizedBox(height: 12),
                _buildResultItem(Icons.warning_amber_rounded, "Warnings", "Red flags indicating highly suspicious or dangerous misinformation.", Colors.orange),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildResultItem(IconData icon, String title, String desc, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(desc, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipsSection extends StatelessWidget {
  const _TipsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "💡 Tips for Best Use",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTip("Share original images, not screenshots, for better deepfake detection."),
          _buildTip("Provide at least a full sentence for text verification."),
          _buildTip("Always review the provided sources before making a conclusion."),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}

class _FAQSection extends StatelessWidget {
  const _FAQSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "❓ FAQ",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFAQItem("Is my data private?", "Yes. We only analyze the text or image temporarily and do not store your personal shares."),
          _buildFAQItem("How long does verification take?", "Usually a few seconds. You'll get a notification as soon as it's done!"),
          _buildFAQItem("Can it detect all fake news?", "While highly accurate, it's not perfect. It's a tool to assist you, but critical thinking is always required."),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Builder(
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(answer, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              ),
            ],
          ),
        );
      }
    );
  }
}

class _CallToAction extends StatelessWidget {
  const _CallToAction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: ElevatedButton(
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: GlobalColors.mainColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              "Start Verifying Now",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
