import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  
  final Rx<Map<String, dynamic>?> currentUser = Rx<Map<String, dynamic>?>(null);
  final RxString token = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  bool get isLoggedIn => token.value.isNotEmpty;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _lastTokenExtendKey = 'last_token_extend_date';

  @override
  void onInit() {
    super.onInit();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      final savedUser = prefs.getString(_userKey);
      
      if (savedToken != null && savedToken.isNotEmpty) {
        token.value = savedToken;
        // Note: In a real app, you'd also restore user data
        // For now, we'll just use the token
      }
    } catch (e) {
      print('Error loading token: $e');
    } finally {
      isInitialized.value = true;
    }
  }

  Future<void> _saveToken(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  Future<void> _clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    isLoading.value = true;
    try {
      final result = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
      
      if (result['success'] == true) {
        token.value = result['token'];
        currentUser.value = result['user'];
        await _saveToken(result['token']);
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Signup failed');
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    try {
      final result = await _authService.signIn(
        email: email,
        password: password,
      );
      
      if (result['success'] == true) {
        token.value = result['token'];
        currentUser.value = result['user'];
        await _saveToken(result['token']);
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Login failed');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> anonymousSignUp({String? name}) async {
    isLoading.value = true;
    try {
      final result = await _authService.anonymousSignUp(name: name);
      
      if (result['success'] == true) {
        token.value = result['token'];
        currentUser.value = result['user'];
        await _saveToken(result['token']);
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Anonymous signup failed');
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    token.value = '';
    currentUser.value = null;
    await _clearToken();
  }

  // Check if current user is anonymous (no email)
  bool get isAnonymous {
    if (currentUser.value == null) return false;
    final email = currentUser.value?['email'];
    return email == null || email.toString().isEmpty;
  }

  // Get user name
  String get userName => currentUser.value?['name']?.toString() ?? 'User';

  // Get user email
  String get userEmail => currentUser.value?['email']?.toString() ?? '';

  // Upgrade anonymous user to registered user
  Future<bool> upgradeAnonymousUser({
    required String email,
    required String password,
    required String name,
  }) async {
    if (token.value.isEmpty) {
      Get.snackbar('Error', 'Not logged in');
      return false;
    }

    isLoading.value = true;
    try {
      final result = await _authService.upgradeAnonymousUser(
        token: token.value,
        email: email,
        password: password,
        name: name,
      );

      if (result['success'] == true) {
        token.value = result['token'];
        currentUser.value = result['user'];
        await _saveToken(result['token']);
        await _saveUser(result['user']);
        Get.snackbar('Success', 'Account created successfully!');
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Failed to create account');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({String? name, String? email}) async {
    if (token.value.isEmpty) {
      Get.snackbar('Error', 'Not logged in');
      return false;
    }

    isLoading.value = true;
    try {
      final result = await _authService.updateProfile(
        token: token.value,
        name: name,
        email: email,
      );

      if (result['success'] == true) {
        currentUser.value = result['user'];
        await _saveUser(result['user']);
        Get.snackbar('Success', 'Profile updated successfully!');
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Failed to update profile');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch current user profile from server
  Future<void> fetchProfile() async {
    if (token.value.isEmpty) return;

    try {
      final result = await _authService.getProfile(token: token.value);
      if (result['success'] == true) {
        currentUser.value = result['user'];
        await _saveUser(result['user']);
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }

  // Change password
  Future<bool> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    if (token.value.isEmpty) {
      Get.snackbar('Error', 'Not logged in');
      return false;
    }

    isLoading.value = true;
    try {
      final result = await _authService.changePassword(
        token: token.value,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (result['success'] == true) {
        Get.snackbar('Success', result['message'] ?? 'Password changed successfully!');
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Failed to change password');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Save user data to preferences
  Future<void> _saveUser(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  // Check if token should be extended (once per day)
  // Returns true if token was extended, false if already extended today
  Future<bool> prolongTokenIfNeeded() async {
    if (token.value.isEmpty) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastExtendDateStr = prefs.getString(_lastTokenExtendKey);
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastExtendDateStr != null) {
        final lastExtendDate = DateTime.parse(lastExtendDateStr);
        final lastExtendDay = DateTime(lastExtendDate.year, lastExtendDate.month, lastExtendDate.day);
        
        // Already extended today
        if (lastExtendDay.isAtSameMomentAs(today)) {
          return false;
        }
      }

      // Extend token for 7 more days
      final result = await _authService.extendToken(token: token.value);
      
      if (result['success'] == true) {
        // Update token if new one is provided
        if (result['token'] != null) {
          token.value = result['token'];
          await _saveToken(result['token']);
        }
        
        // Save today's date as last extend date
        await prefs.setString(_lastTokenExtendKey, today.toIso8601String());
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error extending token: $e');
      return false;
    }
  }
}
