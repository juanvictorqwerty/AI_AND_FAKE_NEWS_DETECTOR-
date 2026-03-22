import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_fake_news_detector/models/fact_check_result.dart';

class FactCheckService extends GetxService {
  String get baseUrl => dotenv.env['BASE_URL_NODE'] ?? 'http://192.168.1.152:4000';

  /// Search for fact-check results for a given claim
  /// 
  /// [claim] - The claim text to fact-check
  /// [token] - The authentication token
  /// 
  /// Returns a Map with 'success' boolean and either 'result' (FactCheckResult) or 'message' (error)
  Future<Map<String, dynamic>> searchFactCheck({
    required String claim,
    required String token,
  }) async {
    try {
      final url = '$baseUrl/fact-check/search';
      print('FactCheckService: Calling $url');
      
      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode({
          'claim': claim,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('FactCheckService: Response status=${response.statusCode}, body=${response.body}');
      
      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server returned empty response. Status: ${response.statusCode}',
        };
      }

      final body = jsonDecode(response.body);

      // Check success field from backend
      if (body['success'] == true) {
        final result = FactCheckResult.fromJson(body);
        return {
          'success': true,
          'result': result,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Fact-check failed',
        };
      }
    } catch (e) {
      print('FactCheckService: Error $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}
