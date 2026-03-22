import 'package:ai_fake_news_detector/pages/LoginScreen.dart';
import 'package:ai_fake_news_detector/pages/HomePage.dart';
import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';
import 'package:ai_fake_news_detector/widgets/text.form.global.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class SignUp extends StatefulWidget {
  SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
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
                  "Create account",
                  style: TextStyle(
                    color: GlobalColors.textColor,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                // Name input
                TextFormGlobal(
                  controller: nameController,
                  text: 'Name',
                  obscure: false,
                  textInputType: TextInputType.text,
                ),

                const SizedBox(height: 10),

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

                const SizedBox(
                  height: 10,
                ),

                TextFormGlobal(
                  controller:confirmPasswordController ,
                  text:'Confirm password',
                  textInputType: TextInputType.text,
                  obscure: false,
                ),

                const SizedBox(height: 10),

                BigButton(
                  text: 'Sign Up',
                  color: GlobalColors.mainColor,
                  isLoading: _isLoading,
                  onTap: _isLoading ? null : () async {
                    // Validate inputs
                    if (emailController.text.isEmpty || 
                        passwordController.text.isEmpty || 
                        nameController.text.isEmpty) {
                      Get.snackbar('Error', 'Please fill in all fields');
                      return;
                    }

                    if (passwordController.text != confirmPasswordController.text) {
                      Get.snackbar('Error', 'Passwords do not match');
                      return;
                    }

                    setState(() => _isLoading = true);

                    // Call signup API
                    final authController = Get.find<AuthController>();
                    final success = await authController.signUp(
                      email: emailController.text,
                      password: passwordController.text,
                      name: nameController.text,
                    );

                    if (success) {
                      Get.offAll(() => Homepage());
                    }
                    if (mounted) setState(() => _isLoading = false);
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
              "Have an account ?",
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
                    builder:(context)=>Login()
                ),
                );
              },
              child: Text(
                " connect !",
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
