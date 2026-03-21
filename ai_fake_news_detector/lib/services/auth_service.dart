import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService extends GetxService {
  String get baseUrl => dotenv.env['BASE_URL_NODE'] ?? 'http://192.168.1.152:4000';

  // Sign up with email and password
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Server returned empty response. Status: ${response.statusCode}'};
      }

      final body = jsonDecode(response.body);

      // Check success field from backend
      if (body['success'] == true) {
        return {
          'success': true,
          'user': body['user'],
          'token': body['token'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}. URL: $baseUrl/auth/signup',
      };
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final url = '$baseUrl/auth/signin';
      print('SignIn URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('SignIn Response: status=${response.statusCode}, body=${response.body}');
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response. Status: ${response.statusCode}'};
      }

      final body = jsonDecode(response.body);

      // Check success field from backend
      if (body['success'] == true) {
        return {
          'success': true,
          'user': body['user'],
          'token': body['token'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('SignIn Error: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Extend/refresh token - prolongs token validity for 7 more days
  Future<Map<String, dynamic>> extendToken({required String token}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/extend-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Server returned empty response. Status: ${response.statusCode}'};
      }

      final body = jsonDecode(response.body);

      if (body['success'] == true) {
        return {
          'success': true,
          'token': body['token'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Token extension failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Anonymous sign up - no email or password required
  Future<Map<String, dynamic>> anonymousSignUp({String? name}) async {
    try {
      print('anonymousSignUp: Calling $baseUrl/auth/anonymous-signup');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/anonymous-signup'),
        body: name != null ? jsonEncode({'name': name}) : jsonEncode({}),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('anonymousSignUp: Response status=${response.statusCode}, body=${response.body}');
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Server returned empty response. Status: ${response.statusCode}'};
      }

      final body = jsonDecode(response.body);

      // Check success field from backend
      if (body['success'] == true) {
        return {
          'success': true,
          'user': body['user'],
          'token': body['token'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Anonymous signup failed',
        };
      }
    } catch (e) {
      print('anonymousSignUp: Error $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}
