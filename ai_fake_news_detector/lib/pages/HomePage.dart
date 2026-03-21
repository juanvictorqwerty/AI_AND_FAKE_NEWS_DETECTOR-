import 'package:ai_fake_news_detector/pages/SettingsPage.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:flutter/material.dart';

class Homepage extends StatelessWidget {
  const Homepage({super.key});

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
                    Text("Hello world")
                  ],
                ),
            )
        ),
      ),
    );
  }
}