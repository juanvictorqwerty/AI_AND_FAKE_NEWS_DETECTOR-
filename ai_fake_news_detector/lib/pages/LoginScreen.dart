import 'package:ai_fake_news_detector/pages/SignUpScreen.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/auth_button.global.dart';
import 'package:ai_fake_news_detector/widgets/text.form.global.dart';
import 'package:flutter/material.dart';

class Login extends StatelessWidget {
  Login({super.key});
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

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
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // vertically centered
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Connection",
                  style: TextStyle(
                    color: GlobalColors.textColor,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                // Email input
                TextFormGlobal(
                  controller: emailController,
                  text: 'Email',
                  obscure: false,
                  textInputType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 10),

                // Password input
                TextFormGlobal(
                  controller: passwordController,
                  text: 'Password',
                  textInputType: TextInputType.text,
                  obscure: true,
                ),

                const SizedBox(height: 10),

                AuthButton(
                  text: 'Login',
                  color: GlobalColors.mainColor,
                  onTap: () {
                    print('Login tapped');
                  },
                ),

                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    "Or",
                    style: TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 20),
                AuthButton(
                  text: "Connect anonymously",
                  color: Colors.black,
                  onTap: (){
                    print("Continue without account");
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 50,
        color: GlobalColors.mainColor,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account ?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            InkWell(
              onTap: (){
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder:(context)=>SignUp()
                    ),
                );
              },
              child: Text(
                "Create one !",
                style: TextStyle(
                  color: const Color.fromARGB(255, 2, 236, 244),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}