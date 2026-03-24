import 'package:ai_fake_news_detector/utils/global.colors.dart';
import 'package:ai_fake_news_detector/widgets/big_button.global.dart';
import 'package:ai_fake_news_detector/widgets/text.form.global.dart';
import 'package:ai_fake_news_detector/widgets/fact_check_result_widget.dart';
import 'package:ai_fake_news_detector/services/fact_check_service.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';
import 'package:ai_fake_news_detector/models/fact_check_result.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FactCheckPage extends StatefulWidget {
  const FactCheckPage({super.key});

  @override
  State<FactCheckPage> createState() => _FactCheckPageState();
}

class _FactCheckPageState extends State<FactCheckPage> {
  final TextEditingController questionController = TextEditingController();
  final FactCheckService _factCheckService = Get.find<FactCheckService>();
  final AuthController _authController = Get.find<AuthController>();
  
  bool _isLoading = false;
  String? _errorMessage;
  FactCheckResult? _result;

  @override
  void dispose() {
    questionController.dispose();
    super.dispose();
  }

  Future<void> _performFactCheck() async {
    final claim = questionController.text.trim();
    
    if (claim.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a claim to fact-check';
      });
      return;
    }

    // Check if user is logged in
    if (_authController.token.value.isEmpty) {
      setState(() {
        _errorMessage = 'Please log in to use fact-checking';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response = await _factCheckService.searchFactCheck(
        claim: claim,
        token: _authController.token.value,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response['success'] == true) {
            _result = response['result'];
            _errorMessage = null;
          } else {
            _errorMessage = response['message'] ?? 'Fact-check failed';
            _result = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred: ${e.toString()}';
          _result = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlobalColors.mainColor,
        title: const Text(
          "Fact Checking",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                TextFormGlobal(
                  controller: questionController,
                  text: "Enter a claim to fact-check",
                  textInputType: TextInputType.text,
                  obscure: false,
                ),
                const SizedBox(height: 20),
                BigButton(
                  text: "Check",
                  onTap: _isLoading ? null : _performFactCheck,
                  color: GlobalColors.mainColor,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_result != null)
                  FactCheckResultWidget(result: _result!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}