
import 'package:ai_fake_news_detector/pages/FactCheckPage.dart';
import 'package:ai_fake_news_detector/pages/SettingsPage.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  @override
  void initState() {
    super.initState();
    _prolongToken();
  }

  Future<void> _prolongToken() async {
    final authController = Get.find<AuthController>();
    final extended = await authController.prolongTokenIfNeeded();
    if (extended) {
      print('Token prolonged for 7 days');
    } else {
      print('Token already prolonged today or not logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: GlobalColors.mainColor,
        title: Text(
          "AI & FAKE NEWS DETECTOR",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 50
          ),
        ),
        actions: <Widget>[
            IconButton( 
              icon: Icon(
                Icons.settings,
                color: Colors.white,
              ),
              onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child:Container(
            width: double.infinity,
              padding: const EdgeInsets.all(15.0),
                child: Column(
                  mainAxisAlignment:MainAxisAlignment.center ,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    BigButton(
                      text: "Fact Check",
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder:(context)=>const FactCheckPage()),
                          );
                      },
                      color: Colors.green
                    ),

                    const SizedBox(height: 20),

                    BigButton(
                      text: "Upload Media", 
                      onTap: (){}, 
                      color: Colors.deepPurpleAccent
                    )
                  ],
                ),
            )
        ),
      ),
    );
  }
}
