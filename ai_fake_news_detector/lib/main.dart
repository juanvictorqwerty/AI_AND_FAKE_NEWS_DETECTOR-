import 'package:ai_fake_news_detector/pages/Splash.view.dart';
import 'package:ai_fake_news_detector/pages/MediaPickerPage.dart';
import 'package:ai_fake_news_detector/pages/MediaResultPage.dart';
import 'package:ai_fake_news_detector/services/auth_service.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/services/fact_check_service.dart';
import 'package:ai_fake_news_detector/services/notification_service.dart';
import 'package:ai_fake_news_detector/services/media_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: "assets/.env");

  
  // Initialize services
  Get.put(AuthService());
  Get.put(AuthController());
  Get.put(FactCheckService());
  Get.put(MediaPickerService());
  
  // Set up MethodChannel before initializing NotificationService
  NotificationService.setupChannel();
  
  Get.put(NotificationService());
  
  runApp(const App());
}

class App extends StatelessWidget {
  const App({Key?key}): super(key: key);
  

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: SplashView(),
      routes: {
        '/media-picker': (context) => const MediaPickerPage(),
        '/media-result': (context) => const MediaResultPage(),
      },
    );
  }
}
