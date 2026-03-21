import 'package:ai_fake_news_detector/pages/SignUpScreen.dart';
import 'package:ai_fake_news_detector/pages/HomePage.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/auth_button.global.dart';
import 'package:ai_fake_news_detector/widgets/text.form.global.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

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

                Column(
                  children: [
                    AuthButton(
                      text: 'Login',
                      color: GlobalColors.mainColor,
                      isLoading: _isLoading,
                      onTap: _isLoading ? null : () async {
                        // Validate inputs
                        if (emailController.text.isEmpty || 
                            passwordController.text.isEmpty) {
                          Get.snackbar('Error', 'Please fill in all fields');
                          return;
                        }

                        setState(() => _isLoading = true);

                        // Call login API
                        final authController = Get.find<AuthController>();
                        final success = await authController.signIn(
                          email: emailController.text,
                          password: passwordController.text,
                        );

                        if (success) {
                          Get.offAll(() => Homepage());
                        }
                        if (mounted) setState(() => _isLoading = false);
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
                      isLoading: _isLoading,
                      onTap: _isLoading ? null : () async {
                        print('Anonymous button tapped');
                        setState(() => _isLoading = true);
                        print('Loading set to true');

                        // Call anonymous signup API
                        final authController = Get.find<AuthController>();
                        print('Got auth controller, calling anonymousSignUp');
                        final success = await authController.anonymousSignUp();
                        print('anonymousSignUp returned: $success');

                        if (success) {
                          Get.offAll(() => Homepage());
                        }
                        if (mounted) setState(() => _isLoading = false);
                      },
                    ),
                  ],
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
