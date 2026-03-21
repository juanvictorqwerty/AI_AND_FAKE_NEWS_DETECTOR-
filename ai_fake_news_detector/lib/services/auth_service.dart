import 'package:get/get.dart';
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
      final response = await GetHttpClient().post(
        '$baseUrl/auth/signup',
        body: {
          'email': email,
          'password': password,
          'name': name,
        },
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'user': response.body['user'],
          'token': response.body['token'],
        };
      } else {
        return {
          'success': false,
          'message': response.body['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await GetHttpClient().post(
        '$baseUrl/auth/signin',
        body: {
          'email': email,
          'password': password,
        },
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': response.body['user'],
          'token': response.body['token'],
        };
      } else {
        return {
          'success': false,
          'message': response.body['message'] ?? 'Login failed',
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
      final response = await GetHttpClient().post(
        '$baseUrl/auth/anonymous-signup',
        body: name != null ? {'name': name} : {},
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'user': response.body['user'],
          'token': response.body['token'],
        };
      } else {
        return {
          'success': false,
          'message': response.body['message'] ?? 'Anonymous signup failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}
