import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';
import 'package:ai_fake_news_detector/widgets/text.form.global.dart';
import 'package:flutter/material.dart';

class FactCheckPage extends StatefulWidget {
  const FactCheckPage({super.key});

  @override
  State<FactCheckPage> createState() => _FactCheckPageState();
}

class _FactCheckPageState extends State<FactCheckPage> {
  final TextEditingController questionController=TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlobalColors.mainColor,
        title: Text(
          "Fact Checking",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 50
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(15.0),
            child: SafeArea(
              child: Column(
                children: [
                  TextFormGlobal(
                    controller: questionController, 
                    text: "Your question", 
                    textInputType: TextInputType.text, 
                    obscure: false
                  ),

                  const SizedBox(height: 20),

                  BigButton(
                    text: "Check", 
                    onTap: (){}, 
                    color: GlobalColors.mainColor
                  )
                ],
              )
            ),
          )
        ),
      ),
    );
  }
}